# Hey emacs! This is a -*- Perl -*- script!
#
# Lintian::IO::Select -- Perl utility functions for lintian
#
# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::IO::Select;

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

our @EXPORT_OK;

BEGIN {

    @EXPORT_OK = qw(
      unpack_and_index_piped_tar
    );
}

use Const::Fast;
use IPC::Open3;
use IO::Select;
use Symbol;
use Unicode::UTF8 qw(encode_utf8);

# read up to 40kB at a time.  this happens to be 4096 "tar records"
# (with a block-size of 512 and a block factor of 20, which appear to
# be the defaults).  when we do full reads and writes of READ_SIZE (the
# OS willing), the receiving end will never be with an incomplete
# record.
const my $TAR_RECORD_SIZE => 20 * 512;

# using 4096 * $TAR_RECORD_SIZE tripped up older kernels < 5.7
const my $READ_CHUNK => 4 * 1024;

const my $EMPTY => q{};

=head1 NAME

Lintian::IO::Select - process functions based on IO::Select

=head1 SYNOPSIS

 use Lintian::IO::Select;

=head1 DESCRIPTION

This module contains process functions based on IO::Select.

=head1 FUNCTIONS

=over 4

=item unpack_and_index_piped_tar

=cut

sub unpack_and_index_piped_tar {
    my ($command, $basedir) = @_;

    my @pids;

    my $select = IO::Select->new;

    my $produce_stdin;
    my $produce_stdout;
    my $produce_stderr = gensym;

    my @produce_command = @{$command};

    my $produce_pid;
    eval{
        $produce_pid = open3(
            $produce_stdin, $produce_stdout,
            $produce_stderr, @produce_command
        );
    };
    die map { encode_utf8($_) } $@ if $@;

    close $produce_stdin;

    push(@pids, $produce_pid);

    $select->add($produce_stdout, $produce_stderr);

    my $extract_stdin;
    my $extract_stdout;
    my $extract_stderr = gensym;

    my @extract_command = (
        qw(tar --no-same-owner --no-same-permissions --touch --extract --file - -C),
        $basedir
    );

    my $extract_pid;
    eval{
        $extract_pid = open3(
            $extract_stdin, $extract_stdout,
            $extract_stderr, @extract_command
        );
    };
    die map { encode_utf8($_) } $@ if $@;

    push(@pids, $extract_pid);

    $select->add($extract_stdout, $extract_stderr);

    my @index_options
      = qw(--list --verbose --utc --full-time --quoting-style=c --file -);

    my $named_stdin;
    my $named_stdout;
    my $named_stderr = gensym;

    my @named_command = ('tar', @index_options);

    my $named_pid;
    eval{
        $named_pid
          = open3($named_stdin, $named_stdout, $named_stderr, @named_command);
    };
    die map { encode_utf8($_) } $@ if $@;

    push(@pids, $named_pid);

    $select->add($named_stdout, $named_stderr);

    my $numeric_stdin;
    my $numeric_stdout;
    my $numeric_stderr = gensym;

    my @numeric_command = ('tar', '--numeric-owner', @index_options);

    my $numeric_pid;
    eval{
        $numeric_pid = open3(
            $numeric_stdin, $numeric_stdout,
            $numeric_stderr, @numeric_command
        );
    };
    die map { encode_utf8($_) } $@ if $@;

    push(@pids, $numeric_pid);

    $select->add($numeric_stdout, $numeric_stderr);

    my $named = $EMPTY;
    my $numeric = $EMPTY;

    my $produce_errors = $EMPTY;
    my $extract_errors = $EMPTY;
    my $named_errors = $EMPTY;

    while (my @ready = $select->can_read) {

        for my $handle (@ready) {

            my $buffer;
            my $length = sysread($handle, $buffer, $READ_CHUNK);

            die encode_utf8("Error from child: $!\n")
              unless defined $length;

            if ($length == 0){
                if ($handle == $produce_stdout) {
                    close $extract_stdin;
                    close $named_stdin;
                    close $numeric_stdin;
                }
                $select->remove($handle);
                next;
            }

            if ($handle == $produce_stdout) {
                print {$extract_stdin} $buffer;
                print {$named_stdin} $buffer;
                print {$numeric_stdin} $buffer;

            } elsif ($handle == $named_stdout) {
                $named .= $buffer;

            } elsif ($handle == $numeric_stdout) {
                $numeric .= $buffer;

            } elsif ($handle == $produce_stderr) {
                $produce_errors .= $buffer;

            } elsif ($handle == $extract_stderr) {
                $extract_errors .= $buffer;

            } elsif ($handle == $named_stderr) {
                $named_errors .= $buffer;

                # } else {
                #   die encode_utf8("Shouldn't be here\n");
            }
        }
    }

    close $produce_stdout;
    close $produce_stderr;

    close $extract_stdout;
    close $extract_stderr;

    close $named_stdout;
    close $named_stderr;

    close $numeric_stdout;
    close $numeric_stderr;

    waitpid($_, 0) for @pids;

    my $tar_errors = ($produce_errors // $EMPTY) . ($extract_errors // $EMPTY);
    my $index_errors = $named_errors;

    return ($named, $numeric, $tar_errors, $index_errors);
}

=back

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

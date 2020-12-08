# Hey emacs! This is a -*- Perl -*- script!
#
# Lintian::IO::Async -- Perl utility functions for lintian
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

package Lintian::IO::Async;

use v5.20;
use warnings;
use utf8;
use autodie;

use Exporter qw(import);

our @EXPORT_OK;

BEGIN {

    @EXPORT_OK = qw(
      get_deb_info
      safe_qx
      unpack_and_index_piped_tar
    );
}

use Const::Fast;
use IO::Async::Loop;
use IO::Async::Process;

use Lintian::Deb822::File;
use Lintian::Index::Item;

# read up to 40kB at a time.  this happens to be 4096 "tar records"
# (with a block-size of 512 and a block factor of 20, which appear to
# be the defaults).  when we do full reads and writes of READ_SIZE (the
# OS willing), the receiving end will never be with an incomplete
# record.
const my $READ_SIZE => 4096 * 20 * 512;

const my $EMPTY => q{};
const my $COLON => q{:};
const my $NEWLINE => qq{\n};

const my $WAIT_STATUS_SHIFT => 8;

=head1 NAME

Lintian::IO::Async - process functions based on IO::Async

=head1 SYNOPSIS

 use Lintian::IO::Async qw(safe_qx);

=head1 DESCRIPTION

This module contains process functions based on IO::Async.

=head1 FUNCTIONS

=over 4

=item C<safe_qx(@cmd)>

Emulates the C<qx()> operator but with array argument only.

=cut

sub safe_qx {
    my @command = @_;

    my $loop = IO::Async::Loop->new;
    my $future = $loop->new_future;
    my $status;

    $loop->run_child(
        command => [@command],
        on_finish => sub {
            my ($pid, $exitcode, $stdout, $stderr) = @_;
            $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            if ($status) {
                my $message = "Command @command exited with status $status";
                $message .= ": $stderr" if length $stderr;
                $future->fail($message);
                return;
            }

            $future->done($stdout);
        });

    $loop->await($future);

    if ($future->is_failed) {
        $? = $status;
        return $future->failure;
    }

    $? = 0;

    # will raise an exception in case of failure
    return $future->get;
}

=item get_deb_info(DEBFILE)

Extracts the control file from DEBFILE and returns it as a hashref.

DEBFILE must be an ar file containing a "control.tar.gz" member, which
in turn should contain a "control" file.  If the "control" file is
empty this will return an empty list.

Note: the control file is only expected to have a single paragraph and
thus only the first is returned (in the unlikely case that there are
more than one).

=cut

sub get_deb_info {
    my ($path) = @_;

    # dpkg-deb -f $file is very slow. Instead, we use ar and tar.

    my $loop = IO::Async::Loop->new;

    # get control tarball from deb
    my $dpkgerror;
    my $dpkgfuture = $loop->new_future;
    my @dpkgcommand = ('dpkg-deb', '--ctrl-tarfile', $path);
    my $dpkgprocess = IO::Async::Process->new(
        command => [@dpkgcommand],
        stdout => { via => 'pipe_read' },
        stderr => { into => \$dpkgerror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            if ($status) {
                my $message= "Non-zero status $status from @dpkgcommand";
                $message .= $COLON . $NEWLINE . $dpkgerror
                  if length $dpkgerror;
                $dpkgfuture->fail($message);
                return;
            }

            $dpkgfuture->done("Done with @dpkgcommand");
            return;
        });

    my $control;

    # get the control file
    my $tarerror;
    my $tarfuture = $loop->new_future;
    my @tarcommand = qw{tar --wildcards -xO -f - *control};
    my $tarprocess = IO::Async::Process->new(
        command => [@tarcommand],
        stdin => { via => 'pipe_write' },
        stdout => { into => \$control },
        stderr => { into => \$tarerror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            if ($status) {
                my $message = "Non-zero status $status from @tarcommand";
                $message .= $COLON . $NEWLINE . $tarerror
                  if length $tarerror;
                $tarfuture->fail($message);
                return;
            }

            $tarfuture->done("Done with @tarcommand");
            return;
        });

    $tarprocess->stdin->configure(write_len => $READ_SIZE);

    $dpkgprocess->stdout->configure(
        read_len => $READ_SIZE,
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length ${$buffref}) {
                $tarprocess->stdin->write(${$buffref});
                ${$buffref} = $EMPTY;
            }

            if ($eof) {
                $tarprocess->stdin->close_when_empty;
            }

            return 0;
        },
    );

    $loop->add($dpkgprocess);
    $loop->add($tarprocess);

    # awaits, and dies on failure with message from failed constituent
    my $composite = Future->needs_all($dpkgfuture, $tarfuture);
    $composite->get;

    my $primary = Lintian::Deb822::File->new;
    my @sections = $primary->parse_string($control);

    return $sections[0];
}

=item unpack_and_index_piped_tar

=cut

sub unpack_and_index_piped_tar {
    my ($command, $basedir) = @_;

    my $loop = IO::Async::Loop->new;

    # get system tarball from deb
    my $deberror;
    my $dpkgdeb = $loop->new_future;
    my $debprocess = IO::Async::Process->new(
        command => $command,
        stdout => { via => 'pipe_read' },
        stderr => { into => \$deberror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            if ($status) {
                my $message
                  = "Non-zero status $status from dpkg-deb for control";
                $message .= $COLON . $NEWLINE . $deberror
                  if length $deberror;
                $dpkgdeb->fail($message);
                return;
            }

            $dpkgdeb->done('Done with dpkg-deb');
            return;
        });

    # extract the tarball's contents
    my $extracterror;
    my $extractor = $loop->new_future;
    my $extractprocess = IO::Async::Process->new(
        command => [
            qw(tar --no-same-owner --no-same-permissions --touch --extract --file - -C),
            $basedir
        ],
        stdin => { via => 'pipe_write' },
        stderr => { into => \$extracterror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            if ($status) {
                my $message = "Non-zero status $status from extract tar";
                $message .= $COLON . $NEWLINE . $extracterror
                  if length $extracterror;
                $extractor->fail($message);
                return;
            }

            $extractor->done('Done with extract tar');
            return;
        });

    my @tar_options
      = qw(--list --verbose --utc --full-time --quoting-style=c --file -);

    # create index (named-owner)
    my $named;
    my $namederror;
    my $namedindexer = $loop->new_future;
    my $namedindexprocess = IO::Async::Process->new(
        command => ['tar', @tar_options],
        stdin => { via => 'pipe_write' },
        stdout => { into => \$named },
        stderr => { into => \$namederror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            if ($status) {
                my $message = "Non-zero status $status from index tar";
                $message .= $COLON . $NEWLINE . $namederror
                  if length $namederror;
                $namedindexer->fail($message);
                return;
            }

            $namedindexer->done('Done with named index tar');
            return;
        });

    # create index (numeric-owner)
    my $numeric;
    my $numericerror;
    my $numericindexer = $loop->new_future;
    my $numericindexprocess = IO::Async::Process->new(
        command =>['tar', '--numeric-owner', @tar_options],
        stdin => { via => 'pipe_write' },
        stdout => { into => \$numeric },
        stderr => { into => \$numericerror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            if ($status) {
                my $message = "Non-zero status $status from index tar";
                $message .= $COLON . $NEWLINE . $numericerror
                  if length $numericerror;
                $numericindexer->fail($message);
                return;
            }

            $numericindexer->done('Done with tar');
            return;
        });

    $extractprocess->stdin->configure(write_len => $READ_SIZE,);
    $namedindexprocess->stdin->configure(write_len => $READ_SIZE,);
    $numericindexprocess->stdin->configure(write_len => $READ_SIZE,);

    $debprocess->stdout->configure(
        read_len => $READ_SIZE,
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length ${$buffref}) {
                $extractprocess->stdin->write(${$buffref});
                $namedindexprocess->stdin->write(${$buffref});
                $numericindexprocess->stdin->write(${$buffref});

                ${$buffref} = $EMPTY;
            }

            if ($eof) {
                $extractprocess->stdin->close_when_empty;
                $namedindexprocess->stdin->close_when_empty;
                $numericindexprocess->stdin->close_when_empty;
            }

            return 0;
        },
    );

    $loop->add($debprocess);
    $loop->add($extractprocess);
    $loop->add($namedindexprocess);
    $loop->add($numericindexprocess);

    my $composite
      = Future->needs_all($dpkgdeb, $extractor, $namedindexer,$numericindexer);

    # awaits, and dies on failure with message from failed constituent
    $composite->get;

    my $extract_errors = ($deberror // $EMPTY) . ($extracterror // $EMPTY);
    my $index_errors = $namederror;

    return ($named, $numeric, $extract_errors, $index_errors);
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

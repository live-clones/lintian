# -*- perl -*- Lintian::Index::Installed
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

package Lintian::Index::Installed;

use v5.20;
use warnings;
use utf8;
use autodie;

use IO::Async::Loop;
use IO::Async::Process;
use Path::Tiny;

use Lintian::Index::Item;
use Lintian::IO::Async qw(safe_qx);

# Read up to 40kB at the time.  This happens to be 4096 "tar records"
# (with a block-size of 512 and a block factor of 20, which appears to
# be the default).  When we do full reads and writes of READ_SIZE (the
# OS willing), the receiving end will never be with an incomplete
# record.
use constant READ_SIZE => 4096 * 1024 * 10;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};
use constant SLASH => q{/};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Index',
  'Lintian::Index::Ar',
  'Lintian::Index::FileInfo',
  'Lintian::Index::Java',
  'Lintian::Index::Md5sums',
  'Lintian::Index::Objdump',
  'Lintian::Index::Scripts',
  'Lintian::Index::Strings';

=encoding utf-8

=head1 NAME

Lintian::Index::Installed -- An index of an installed file set

=head1 SYNOPSIS

 use Lintian::Index::Installed;

 # Instantiate via Lintian::Index::Installed
 my $orig = Lintian::Index::Installed->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
installed file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4

=item collect

=item unpack

=cut

sub collect {
    my ($self, $groupdir) = @_;

    # binary packages are anchored to the system root
    # allow absolute paths and symbolic links
    $self->anchored(1);
    my $basedir = path($groupdir)->child('unpacked')->stringify;
    $self->basedir($basedir);

    $self->unpack($groupdir);
    $self->load;

    $self->add_md5sums;
    $self->add_ar($groupdir);

    $self->add_fileinfo;
    $self->add_scripts;
    $self->add_objdump;
    $self->add_strings;
    $self->add_java;

    return;
}

sub unpack {
    my ($self, $groupdir) = @_;

    path($self->basedir)->remove_tree
      if -d $self->basedir;

    for my $file (qw(index-errors unpacked-errors)) {
        unlink("$groupdir/$file")
          if -e "$groupdir/$file";
    }

    mkdir($self->basedir, 0777);

    my $loop = IO::Async::Loop->new;

    # get system tarball from deb
    my $deberror;
    my $dpkgdeb = $loop->new_future;
    my $debprocess = IO::Async::Process->new(
        command => ['dpkg-deb', '--fsys-tarfile', "$groupdir/deb"],
        stdout => { via => 'pipe_read' },
        stderr => { into => \$deberror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message
                  = "Non-zero status $status from dpkg-deb for control";
                $message .= COLON . NEWLINE . $deberror
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
            'tar', '--no-same-owner', '--no-same-permissions',
            '-mxf','-', '-C', $self->basedir
        ],
        stdin => { via => 'pipe_write' },
        stderr => { into => \$extracterror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message = "Non-zero status $status from extract tar";
                $message .= COLON . NEWLINE . $extracterror
                  if length $extracterror;
                $extractor->fail($message);
                return;
            }

            $extractor->done('Done with extract tar');
            return;
        });

    my @tar_options= (
        '--list', '--verbose',
        '--utc', '--full-time',
        '--quoting-style=c','--file'
    );

    # create index (named-owner)
    my $named;
    my $namederror;
    my $namedindexer = $loop->new_future;
    my $namedindexprocess = IO::Async::Process->new(
        command => ['tar', @tar_options, '-'],
        stdin => { via => 'pipe_write' },
        stdout => { into => \$named },
        stderr => { into => \$namederror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message = "Non-zero status $status from index tar";
                $message .= COLON . NEWLINE . $namederror
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
        command =>['tar', '--numeric-owner', @tar_options, '-'],
        stdin => { via => 'pipe_write' },
        stdout => { into => \$numeric },
        stderr => { into => \$numericerror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message = "Non-zero status $status from index tar";
                $message .= COLON . NEWLINE . $numericerror
                  if length $numericerror;
                $numericindexer->fail($message);
                return;
            }

            $numericindexer->done('Done with tar');
            return;
        });

    $extractprocess->stdin->configure(write_len => READ_SIZE,);
    $namedindexprocess->stdin->configure(write_len => READ_SIZE,);
    $numericindexprocess->stdin->configure(write_len => READ_SIZE,);

    $debprocess->stdout->configure(
        read_len => READ_SIZE,
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length $$buffref) {
                $extractprocess->stdin->write($$buffref);
                $namedindexprocess->stdin->write($$buffref);
                $numericindexprocess->stdin->write($$buffref);

                $$buffref = EMPTY;
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

    path("$groupdir/unpacked-errors")->append($deberror // EMPTY);
    path("$groupdir/unpacked-errors")->append($extracterror // EMPTY);
    path("$groupdir/index-errors")->append($namederror // EMPTY);

    my @named_owner = split(/\n/, $named);
    my @numeric_owner = split(/\n/, $numeric);

    my %all;
    for my $line (@named_owner) {

        my $entry = Lintian::Index::Item->new;
        $entry->init_from_tar_output($line);

        $all{$entry->name} = $entry;
    }

    # get numerical owners from second list
    for my $line (@numeric_owner) {

        my $entry = Lintian::Index::Item->new;
        $entry->init_from_tar_output($line);

        die 'Numerical index lists extra files for file name '. $entry->name
          unless exists $all{$entry->name};

        # copy numerical uid and gid
        $all{$entry->name}->uid($entry->owner);
        $all{$entry->name}->gid($entry->group);
    }

    $self->catalog(\%all);

    # remove error files if empty
    unlink("$groupdir/index-errors")
      if -z "$groupdir/index-errors";
    unlink("$groupdir/unpacked-errors")
      if -z "$groupdir/unpacked-errors";

    # fix permissions
    safe_qx('chmod', '-R', 'u+rwX,go-w', $self->basedir);

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.
Substantial portions adapted from code written by Russ Allbery, Niels Thykier, and others.

=head1 SEE ALSO

lintian(1)

L<Lintian::Index>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

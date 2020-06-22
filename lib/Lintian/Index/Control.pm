# -*- perl -*- Lintian::Index::Control
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

package Lintian::Index::Control;

use v5.20;
use warnings;
use utf8;
use autodie;

use IO::Async::Loop;
use IO::Async::Process;
use Path::Tiny;

use Lintian::File::Path;
use Lintian::Util qw(safe_qx);

# read up to 40kB at a time.  this happens to be 4096 "tar records"
# (with a block-size of 512 and a block factor of 20, which appear to
# be the defaults).  when we do full reads and writes of READ_SIZE (the
# OS willing), the receiving end will never be with an incomplete
# record.
use constant READ_SIZE => 4096 * 20 * 512;

use constant EMPTY => q{};
use constant COLON => q{:};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Index','Lintian::Index::Scripts';
with 'Lintian::Index','Lintian::Index::Control::Scripts';

=encoding utf-8

=head1 NAME

Lintian::Index::Control -- An index of a control file set

=head1 SYNOPSIS

 use Lintian::Index::Control;

 # Instantiate via Lintian::Index::Control
 my $orig = Lintian::Index::Control->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
control file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4

=item collect

=item unpack

=cut

sub collect {
    my ($self, $groupdir) = @_;

    # control files are not installed relative to the system root
    # disallow absolute paths and symbolic links
    my $basedir = path($groupdir)->child('control')->stringify;
    $self->basedir($basedir);

    $self->unpack($groupdir);
    $self->load;

    $self->add_scripts;
    $self->add_control;

    return;
}

sub unpack {
    my ($self, $groupdir) = @_;

    path($self->basedir)->remove_tree
      if -d $self->basedir;

    my $controlerrorspath = "$groupdir/control-errors";
    my $indexerrorspath = "$groupdir/control-index-errors";

    for my $path ($controlerrorspath, $indexerrorspath) {
        unlink($path) if -e $path;
    }

    mkdir($self->basedir, 0777);

    my $debpath = "$groupdir/deb";
    return
      unless -f $debpath;

    my $loop = IO::Async::Loop->new;

    # get control tarball from deb
    my $deberror;
    my $dpkgdeb = $loop->new_future;
    my @debcommand = ('dpkg-deb', '--ctrl-tarfile', $debpath);
    my $debprocess = IO::Async::Process->new(
        command => [@debcommand],
        stdout => { via => 'pipe_read' },
        stderr => { into => \$deberror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message= "Non-zero status $status from @debcommand";
                $message .= COLON . NEWLINE . $deberror
                  if length $deberror;
                $dpkgdeb->fail($message);
                return;
            }

            $dpkgdeb->done("Done with @debcommand");
            return;
        });

    # extract the tarball's contents
    my $extracterror;
    my $extractor = $loop->new_future;
    my @extractcommand = (
        'tar', '--no-same-owner','--no-same-permissions', '-mxf',
        '-', '-C', $self->basedir
    );
    my $extractprocess = IO::Async::Process->new(
        command => [@extractcommand],
        stdin => { via => 'pipe_write' },
        stderr => { into => \$extracterror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message = "Non-zero status $status from @extractcommand";
                $message .= COLON . NEWLINE . $extracterror
                  if length $extracterror;
                $extractor->fail($message);
                return;
            }

            $extractor->done("Done with @extractcommand");
            return;
        });

    # create index of control.tar.gz
    my $index;
    my $indexerror;
    my $indexer = $loop->new_future;
    my @indexcommand = (
        'tar', '--list','--verbose','--utc','--full-time','--quoting-style=c',
        '--file', '-'
    );
    my $indexprocess = IO::Async::Process->new(
        command => [@indexcommand],
        stdin => { via => 'pipe_write' },
        stdout => { into => \$index },
        stderr => { into => \$indexerror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message = "Non-zero status $status from @indexcommand";
                $message .= COLON . NEWLINE . $indexerror
                  if length $indexerror;
                $indexer->fail($message);
                return;
            }

            $indexer->done("Done with @indexcommand");
            return;
        });

    $extractprocess->stdin->configure(write_len => READ_SIZE);
    $indexprocess->stdin->configure(write_len => READ_SIZE);

    $debprocess->stdout->configure(
        read_len => READ_SIZE,
        on_read => sub {
            my ($stream, $buffref, $eof) = @_;

            if (length $$buffref) {
                $extractprocess->stdin->write($$buffref);
                $indexprocess->stdin->write($$buffref);

                $$buffref = EMPTY;
            }

            if ($eof) {
                $extractprocess->stdin->close_when_empty;
                $indexprocess->stdin->close_when_empty;
            }

            return 0;
        },
    );

    $loop->add($debprocess);
    $loop->add($indexprocess);
    $loop->add($extractprocess);

    my $composite = Future->needs_all($dpkgdeb, $extractor, $indexer);

    # awaits, and dies on failure with message from failed constituent
    $composite->get;

    # not recording dpkg-deb errors anywhere
    path($controlerrorspath)->append($extracterror)
      if length $extracterror;
    path($indexerrorspath)->append($indexerror)
      if length $indexerror;

    my @lines = split(/\n/, $index);

    my %all;
    for my $line (@lines) {

        my $entry = Lintian::File::Path->new;
        $entry->init_from_tar_output($line);

        $all{$entry->name} = $entry;
    }

    $self->catalog(\%all);

    # fix permissions
    safe_qx('chmod', '-R', 'u+rX,o-w', $self->basedir);

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

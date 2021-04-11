# -*- perl -*- Lintian::Processable::Patched
#
# Copyright © 2008 Russ Allbery
# Copyright © 2009 Raphael Geissert
# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Processable::Patched;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Cwd;
use List::SomeUtils qw(uniq);
use IPC::Run3;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Lintian::Index;
use Lintian::Index::Item;

use Moo::Role;
use namespace::clean;

const my $COLON => q{:};
const my $SLASH => q{/};
const my $NEWLINE => qq{\n};

const my $NO_UMASK => 0000;
const my $WAIT_STATUS_SHIFT => 8;

=head1 NAME

Lintian::Processable::Patched - access to sources with Debian patches applied

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Patched provides an interface to collected data about patched sources.

=head1 INSTANCE METHODS

=over 4

=item patched

Returns a index object representing a patched source tree.

=cut

has patched => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $index = Lintian::Index->new;
        $index->basedir($self->basedir . $SLASH . 'unpacked');

        # source packages can be unpacked anywhere; no anchored roots
        $index->anchored(0);

        path($index->basedir)->remove_tree
          if -d $index->basedir;

        print encode_utf8("N: Using dpkg-source to unpack\n")
          if $ENV{'LINTIAN_DEBUG'};

        my $saved_umask = umask;
        umask $NO_UMASK;

        my @unpack_command= (
            qw(dpkg-source -q --no-check --extract),
            $self->path, $index->basedir
        );

        # ignore STDOUT; older versions are not completely quiet with -q
        my $unpack_errors;

        run3(\@unpack_command, \undef, \undef, \$unpack_errors);
        my $status = ($? >> $WAIT_STATUS_SHIFT);

        $unpack_errors = decode_utf8($unpack_errors)
          if length $unpack_errors;

        if ($status) {
            my $message = "Non-zero status $status from @unpack_command";
            $message .= $COLON . $NEWLINE . $unpack_errors
              if length $unpack_errors;

            die encode_utf8($message);
        }

        umask $saved_umask;

        my $index_errors = $index->create_from_basedir;

        my $savedir = getcwd;
        chdir($index->basedir)
          or die encode_utf8('Cannot change to directory ' . $index->basedir);

        # fix permissions
        my @permissions_command
          = ('chmod', '-R', 'u+rwX,o+rX,o-w', $index->basedir);
        my $permissions_errors;

        run3(\@permissions_command, \undef, \undef, \$permissions_errors);

        $permissions_errors = decode_utf8($permissions_errors)
          if length $permissions_errors;

        chdir($savedir)
          or die encode_utf8("Cannot change to directory $savedir");

        $self->hint('unpack-message-for-source', $_)
          for uniq
          split(/\n/, $unpack_errors . $index_errors . $permissions_errors);

        return $index;
    });

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

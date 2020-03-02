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

use strict;
use warnings;
use autodie;

use Path::Tiny;

use Lintian::Index::Patched;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Patched - access to sources with Debian patches applied

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

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

        my $patched = Lintian::Index::Patched->new;

        # source packages can be unpacked anywhere; no anchored roots
        my $basedir = path($self->groupdir)->child('unpacked')->stringify;
        $patched->basedir($basedir);

        $patched->fileinfo_sub(
            sub {
                return $self->file_info(@_);
            });

        my $dbpath = path($self->groupdir)->child('index.db')->stringify;
        $patched->load($dbpath);

        return $patched;
    });

=item index (FILE)

The index of a source package is not very well defined for non-native
source packages.  This method gives the index of the "unpacked"
package (with 3.0 (quilt), this implies patches have been applied).

If you want the index of what is listed in the upstream orig tarballs,
then there is L</orig_index>.

For native packages, the two indices are generally the same as they
only have one tarball and their debian packaging is included in that
tarball.

IMPLEMENTATION DETAIL/CAVEAT: Lintian currently (2.5.11) generates
this by running "find(1)" after unpacking the source package.
This has three consequences.

First it means that (original) owner/group data is lost; Lintian
inserts "root/root" here.  This is usually not a problem as
owner/group information for source packages do not really follow any
standards.

Secondly, permissions are modified by A) umask and B) laboratory
set{g,u}id bits (the laboratory on lintian.d.o has setgid).  This is
*not* corrected/altered.  Note Lintian (usually) breaks if any of the
"user" bits are set in the umask, so that part of the permission bit
I<should> be reliable.

Again, this shouldn't be a problem as permissions in source packages
are usually not important.  Though if accuracy is needed here,
L</orig_index> may used instead (assuming it has the file in
question).

Third, hardlinking information is lost and no attempt has been made
to restore it.

Needs-Info requirements for using I<index>: unpacked

=cut

sub index {
    my ($self, $file) = @_;

    return $self->patched->lookup($file);
}

=item sorted_index

Returns a sorted array of file names listed in the package.  The names
will not have a leading slash (or "./") and can be passed to
L</unpacked ([FILE])> or L</index (FILE)> as is.

The array will not contain the entry for the "root" of the package.

NB: For source packages, please see the
L<"index"-caveat|Lintian::Collect::Source/index (FILE)>.

Needs-Info requirements for using I<sorted_index>: L<Same as index|/index (FILE)>

=cut

sub sorted_index {
    my ($self) = @_;

    return $self->patched->sorted_list;
}

=item index_resolved_path(PATH)

Resolve PATH (relative to the root of the package) and return the
L<entry|Lintian::File::Path> denoting the resolved path.

The resolution is done using
L<resolve_path|Lintian::File::Path/resolve_path([PATH])>.

NB: For source packages, please see the
L<"index"-caveat|Lintian::Collect::Source/index (FILE)>.

Needs-Info requirements for using I<index_resolved_path>: L<Same as index|/index (FILE)>

=cut

sub index_resolved_path {
    my ($self, $path) = @_;

    return $self->patched->resolve_path($path);
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian. Large portions were copied from Collect::Binary.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

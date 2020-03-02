# -*- perl -*- Lintian::Processable::Control
#
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

package Lintian::Processable::Control;

use strict;
use warnings;
use autodie;

use Path::Tiny;

use Lintian::Index::Control;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Control - access to collected control file data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Control provides an interface to control file data.

=head1 INSTANCE METHODS

=over 4

=item control

Returns the index for a binary control file.

=cut

has control => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $control = Lintian::Index::Control->new;

        # control files are not installed relative to the system root
        # disallow absolute paths and symbolic links

        my $basedir = path($self->groupdir)->child('control')->stringify;
        $control->basedir($basedir);

        my $dbpath
          = path($self->groupdir)->child('control-index.db')->stringify;
        $control->load($dbpath);

        return $control;
    });

=item control_index (FILE)

Returns a L<path object|Lintian::File::Path> to FILE in the control.tar.gz.
FILE must be relative to the root of the control.tar.gz and must be
without leading slash (or "./").  If FILE is not in the
control.tar.gz, it returns C<undef>.

To get a list of entries in the control.tar.gz, see
L</sorted_control_index>.  To actually access the underlying file
(e.g. the contents), use L</control ([FILE])>.

Note that the "root directory" (denoted by the empty string) will
always be present, even if the underlying tarball omits it.

Needs-Info requirements for using I<control_index>: bin-pkg-control

=cut

sub control_index {
    my ($self, $file) = @_;

    return $self->control->lookup($file);
}

=item sorted_control_index

Returns a sorted array of file names listed in the control.tar.gz.
The names will not have a leading slash (or "./") and can be passed
to L</control ([FILE])> or L</control_index (FILE)> as is.

The array will not contain the entry for the "root" of the
control.tar.gz.

Needs-Info requirements for using I<sorted_control_index>: L<Same as control_index|/control_index (FILE)>

=cut

sub sorted_control_index {
    my ($self) = @_;

    return $self->control->sorted_list;
}

=item control_index_resolved_path(PATH)

Resolve PATH (relative to the root of the package) and return the
L<entry|Lintian::File::Path> denoting the resolved path.

The resolution is done using
L<resolve_path|Lintian::File::Path/resolve_path([PATH])>.

Needs-Info requirements for using I<control_index_resolved_path>: L<Same as control_index|/control_index (FILE)>

=cut

sub control_index_resolved_path {
    my ($self, $path) = @_;

    return $self->control->resolve_path($path);
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

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

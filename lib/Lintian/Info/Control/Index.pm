# -*- perl -*- Lintian::Info::Control::Index
#
# Copyright © 2019 Felix Lechner
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

package Lintian::Info::Control::Index;

use strict;
use warnings;
use autodie;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Info::Control::Index - access to collected control file data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Info::Control::Index provides an interface to control file data.

=head1 INSTANCE METHODS

=over 4

=item control ([FILE])

B<This method is deprecated>.  Consider using
L</control_index_resolved_path(PATH)> instead, which returns
L<Lintian::Path> objects.

Returns the path to FILE in the control.tar.gz.  FILE must be either a
L<Lintian::Path> object (>= 2.5.13~) or a string denoting the
requested path.  In the latter case, the path must be relative to the
root of the control.tar.gz member and should be normalized.

It is not permitted for FILE to be C<undef>.  If the "root" dir is
desired either invoke this method without any arguments at all, pass
it the correct L<Lintian::Path> or the empty string.

To get a list of entries in the control.tar.gz or the file meta data
of the entries (as L<path objects|Lintian::Path>), see
L</sorted_control_index> and L</control_index (FILE)>.

The caveats of L<unpacked|Lintian::Info::Package/unpacked ([FILE])>
also apply to this method.  However, as the control.tar.gz is not
known to contain symlinks, a simple file type check is usually enough.

Needs-Info requirements for using I<control>: bin-pkg-control

=cut

sub control {
    ## no critic (Subroutines::RequireArgUnpacking)
    # - see L::Collect::unpacked for why
    my $self = shift(@_);
    my $f = $_[0] // '';

    warnings::warnif(
        'deprecated',
        '[deprecated] The control method is deprecated.  '
          . "Consider using \$info->control_index_resolved_path('$f') instead."
          . '  Called' # warnif appends " at <...>"
    );
    return $self->_fetch_extracted_dir('control', 'control', @_);
}

=item control_index (FILE)

Returns a L<path object|Lintian::Path> to FILE in the control.tar.gz.
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

    if (my $cache = $self->{'control_index'}) {

        return $cache->{$file}
          if exists $cache->{$file};

        return;
    }

    my $load_info = {
        'field' => 'control_index',
        'index_file' => 'control-index',
        'index_owner_file' => undef,
        'fs_root_sub' => 'control',
        # Control files are not installed relative to the system root.
        # Accordingly, we forbid absolute paths and symlinks..
        'has_anchored_root_dir' => 0,
    };

    return $self->_fetch_index_data($load_info, $file);
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

    # control_index does all our work for us, so call it if
    # sorted_control_index has not been created yet.
    $self->control_index('')
      unless exists $self->{'sorted_control_index'};

    return @{ $self->{'sorted_control_index'} };
}

=item control_index_resolved_path(PATH)

Resolve PATH (relative to the root of the package) and return the
L<entry|Lintian::Path> denoting the resolved path.

The resolution is done using
L<resolve_path|Lintian::Path/resolve_path([PATH])>.

Needs-Info requirements for using I<control_index_resolved_path>: L<Same as control_index|/control_index (FILE)>

=cut

sub control_index_resolved_path {
    my ($self, $path) = @_;

    return $self->control_index('')->resolve_path($path);
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

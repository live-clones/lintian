# Copyright © 2019 Felix Lechner
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

package Lintian::Processable::Buildinfo;

use strict;
use warnings;

use Carp qw(croak);
use Path::Tiny;

use Lintian::Util qw(get_dsc_info);

use constant EMPTY => q{};
use constant COLON => q{:};
use constant SLASH => q{/};

use Moo;
use namespace::clean;

with 'Lintian::Info::Fields::Files', 'Lintian::Processable';

=head1 NAME

Lintian::Processable::Buildinfo -- A buildinfo file Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable::Buildinfo;

 my $processable = Lintian::Processable::Buildinfo->new;
 $processable->init('path');

=head1 DESCRIPTION

This class represents a 'buildinfo' file that Lintian can process. Objects
of this kind are often part of a L<Lintian::Processable::Group>, which
represents all the files in a changes or buildinfo file.

=head1 INSTANCE METHODS

=over 4

=item init (FILE)

Initializes a new object from FILE.

=cut

sub init {
    my ($self, $file) = @_;

    croak "File $file is not an absolute, resolved path"
      unless $file eq path($file)->realpath->stringify;

    croak "File $file does not exist"
      unless -e $file;

    $self->pkg_path($file);

    $self->pkg_type('buildinfo');
    $self->link_label('buildinfo');

    my $cinfo = get_dsc_info($self->pkg_path)
      or croak $self->pkg_path. ' is not a valid '. $self->pkg_type . ' file';

    my $package = $cinfo->{source};
    my $version = $cinfo->{version};
    my $architecture = $cinfo->{architecture};

    unless (length $package) {
        $package = $self->guess_name($self->pkg_path);
        croak 'Cannot determine the name from '. $self->pkg_path
          unless length $package;
    }

    $self->pkg_name($package // EMPTY);
    $self->pkg_version($version // EMPTY);
    $self->pkg_arch($architecture // EMPTY);

    $self->pkg_src($self->pkg_name);
    $self->pkg_src_version($self->pkg_version);

    $self->extra_fields($cinfo);

    $self->name($self->pkg_name);
    $self->type($self->pkg_type);
    $self->verbatim($cinfo);

    # make sure none of the fields can cause traversal
    $self->clean_field($_)
      for ('pkg_name', 'pkg_version', 'pkg_src', 'pkg_src_version','pkg_arch');

    my $id
      = $self->pkg_type . COLON . $self->pkg_name . SLASH . $self->pkg_version;

    # add architecture unless it is source
    $id .= SLASH . $self->pkg_arch;

    $self->identifier($id);

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

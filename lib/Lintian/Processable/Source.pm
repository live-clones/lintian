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

package Lintian::Processable::Source;

use strict;
use warnings;

use Carp qw(croak);
use Path::Tiny;

use Lintian::Util qw(get_dsc_info strip);

use constant EMPTY => q{};
use constant COLON => q{:};
use constant SLASH => q{/};

use Moo;
use namespace::clean;

with 'Lintian::Collect::Source',
  'Lintian::Processable::Checksums::Md5',
  'Lintian::Processable::Diffstat',
  'Lintian::Processable::Changelog',
  'Lintian::Processable::Fields::Files',
  'Lintian::Processable::FileInfo',
  'Lintian::Processable::Java',
  'Lintian::Processable::Orig',
  'Lintian::Processable::Overrides',
  'Lintian::Processable::Patched',
  'Lintian::Processable::Scripts::Control',
  'Lintian::Processable';

=for Pod::Coverage BUILDARGS

=head1 NAME

Lintian::Processable::Source -- A dsc source package Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable::Source;

 my $processable = Lintian::Processable::Source->new;
 $processable->init('path');

=head1 DESCRIPTION

This class represents a 'dsc' file that Lintian can process. Objects
of this kind are often part of a L<Lintian::Group>, which
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

    $self->path($file);

    $self->type('source');
    $self->link_label('dsc');

    my $dinfo = get_dsc_info($self->path)
      or croak $self->path . ' is not valid dsc file';

    $self->verbatim($dinfo);

    my $name = $dinfo->{source} // EMPTY;
    my $version = $dinfo->{version} // EMPTY;
    my $architecture = 'source';

    # it is its own source package
    my $source = $name;
    my $source_version = $version;

    croak $self->path . ' is missing Source field'
      unless length $name;

    $self->name($name);
    $self->version($version);
    $self->architecture($architecture);
    $self->source($source);
    $self->source_version($source_version);

    # make sure none of these fields can cause traversal
    $self->tainted(1)
      if $self->name ne $name
      || $self->version ne $version
      || $self->architecture ne $architecture
      || $self->source ne $source
      || $self->source_version ne $source_version;

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

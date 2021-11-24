# Copyright © 2019-2020 Felix Lechner
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

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use File::Spec;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::File;

use Moo;
use namespace::clean;

with
  'Lintian::Processable',
  'Lintian::Processable::Diffstat',
  'Lintian::Processable::Changelog',
  'Lintian::Processable::Changelog::Version',
  'Lintian::Processable::Debian::Control',
  'Lintian::Processable::Fields::Files',
  'Lintian::Processable::IsNonFree',
  'Lintian::Processable::Orig',
  'Lintian::Processable::Patched',
  'Lintian::Processable::Source::Components',
  'Lintian::Processable::Source::Format',
  'Lintian::Processable::Source::Overrides',
  'Lintian::Processable::Source::Relation',
  'Lintian::Processable::Source::Repacked';

=for Pod::Coverage BUILDARGS

=head1 NAME

Lintian::Processable::Source -- A dsc source package Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable::Source;

 my $processable = Lintian::Processable::Source->new;
 $processable->init_from_file('path');

=head1 DESCRIPTION

This class represents a 'dsc' file that Lintian can process. Objects
of this kind are often part of a L<Lintian::Group>, which
represents all the files in a changes or buildinfo file.

=head1 INSTANCE METHODS

=over 4

=item init_from_file (PATH)

Initializes a new object from PATH.

=cut

sub init_from_file {
    my ($self, $file) = @_;

    croak encode_utf8("File $file does not exist")
      unless -e $file;

    $self->path($file);
    $self->type('source');

    my $primary = Lintian::Deb822::File->new;
    my @sections = $primary->read_file($self->path)
      or croak encode_utf8($self->path . ' is not valid dsc file');

    $self->fields($sections[0]);

    my $name = $self->fields->value('Source');
    my $version = $self->fields->value('Version');
    my $architecture = 'source';

    # it is its own source package
    my $source_name = $name;
    my $source_version = $version;

    croak encode_utf8($self->path . ' is missing Source field')
      unless length $name;

    $self->name($name);
    $self->version($version);
    $self->architecture($architecture);
    $self->source_name($source_name);
    $self->source_version($source_version);

    # make sure none of these fields can cause traversal
    $self->tainted(1)
      if $self->name ne $name
      || $self->version ne $version
      || $self->architecture ne $architecture
      || $self->source_name ne $source_name
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

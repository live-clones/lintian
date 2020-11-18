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

package Lintian::Processable::Installable;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Path::Tiny;

use Lintian::IPC::Run3 qw(get_deb_info);

use constant COLON => q{:};
use constant SLASH => q{/};

use Moo;
use namespace::clean;

with
  'Lintian::Processable::Installable::Class',
  'Lintian::Processable::Installable::Relation',
  'Lintian::Processable::Changelog',
  'Lintian::Processable::Control',
  'Lintian::Processable::Control::Conffiles',
  'Lintian::Processable::Installed',
  'Lintian::Processable::IsNonFree',
  'Lintian::Processable::Hardening',
  'Lintian::Processable::Objdump',
  'Lintian::Processable::NotJustDocs',
  'Lintian::Processable::Overrides',
  'Lintian::Processable';

=for Pod::Coverage BUILDARGS

=head1 NAME

Lintian::Processable::Installable -- An installation package Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable::Installable;

 my $processable = Lintian::Processable::Installable->new;
 $processable->init('path');

=head1 DESCRIPTION

This class represents a 'deb' or 'udeb' file that Lintian can process. Objects
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

    my $section = get_deb_info($self->path)
      or croak 'could not read control data in ' . $self->path . ": $!";

    $self->fields($section);

    my $name = $self->fields->value('Package');
    my $version = $self->fields->value('Version');
    my $architecture = $self->fields->value('Architecture');
    my $source = $self->fields->value('Source');

    my $source_version = $version;

    unless (length $name) {
        $name = $self->guess_name($self->path);
        croak 'Cannot determine the name from ' . $self->path
          unless length $name;
    }

    # source may be left out if same as $name
    $source = $name
      unless length $source;

    # source probably contains the version in parentheses
    if ($source =~ m/(\S++)\s*\(([^\)]+)\)/){
        $source = $1;
        $source_version = $2;
    }

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

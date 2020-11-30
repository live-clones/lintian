# -*- perl -*-
# Lintian::Debian::Control -- object for fields in d/control

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

package Lintian::Debian::Control;

use v5.20;
use warnings;
use utf8;

use Path::Tiny;
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::Deb822::File;
use Lintian::Deb822::Section;
use Lintian::Util qw($PKGNAME_REGEX);

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Debian::Control - Lintian interface to d/control fields

=head1 SYNOPSIS

    use Lintian::Debian::Control;

=head1 DESCRIPTION

Lintian::Debian::Control provides access to fields in d/control.

=head1 INSTANCE METHODS

=over 4

=item source_fields
=item installable_fields_by_name

=cut

has source_fields => (
    is => 'rw',
    default => sub { return Lintian::Deb822::Section->new; },
    coerce => sub {
        my ($blessedref) = @_;
        return ($blessedref // Lintian::Deb822::Section->new);
    },
);

has installable_fields_by_name => (
    is => 'rw',
    default => sub { {} },
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
);

=item load

=cut

sub load {
    my ($self, $path) = @_;

    return
      unless defined $path;

    return
      unless -r $path;

    my $bytes = path($path)->slurp;
    return
      unless length $bytes;

    return
      unless valid_utf8($bytes);

    my $contents = decode_utf8($bytes);

    my $deb822 = Lintian::Deb822::File->new;

    my @sections;
    eval {@sections = $deb822->parse_string($contents);};

    if (length $@) {
        # If it is a syntax error, ignore it (we emit
        # syntax-error-in-control-file in this case via
        # control-file).
        die map { encode_utf8($_) } $@
          unless $@ =~ /syntax error/;

        return;
    }

    # in theory, one could craft a package in which d/control is empty
    my $source = shift @sections;
    $self->source_fields($source);

    my @named
      = grep { $_->value('Package') =~ m{\A $PKGNAME_REGEX \Z}x }@sections;

    my %by_name = map { $_->value('Package') => $_ } @named;

    $self->installable_fields_by_name(\%by_name);

    return;
}

=item installables

Returns a list of the binary and udeb packages listed in the
F<debian/control>.

=cut

sub installables {
    my ($self) = @_;

    return keys %{$self->installable_fields_by_name};
}

=item installable_package_type (NAME)

Returns package type based on value of the Package-Type (or if absent,
X-Package-Type) field.  If the field is omitted, the default value
"deb" is used.

If NAME is not an installable listed in the source packages
F<debian/control> file, this method return C<undef>.

=cut

sub installable_package_type {
    my ($self, $name) = @_;

    my $type;

    my $fields = $self->installable_fields_by_name->{$name};

    $type = $fields->value('Package-Type') || $fields->value('XC-Package-Type')
      if defined $fields;

    $type ||= 'deb';

    return lc $type;
}

=item installable_fields (PACKAGE)

Returns the Deb822::Section object for the installable. Returns an
empty object if the installable does not exist.

=cut

sub installable_fields {
    my ($self, $package) = @_;

    my $per_package;

    $per_package = $self->installable_fields_by_name->{$package}
      if length $package;

    return ($per_package // Lintian::Deb822::Section->new);
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.
Amended by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# -*- perl -*-
# Lintian::Processable::Source::Fields -- interface to source package data collection

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

package Lintian::Processable::Source::Fields;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Scalar::Util qw(blessed);
use Path::Tiny;
use Try::Tiny;
use Unicode::UTF8 qw(valid_utf8 decode_utf8);

use Lintian::Deb822Parser qw(parse_dpkg_control_string);
use Lintian::Inspect::Changelog::Version;
use Lintian::Relation;
use Lintian::Util
  qw(get_file_checksum open_gz $PKGNAME_REGEX $PKGREPACK_REGEX);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Source::Fields - Lintian interface to source package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'source', '/path/to/lab-entry');
    my $collect = Lintian::Processable::Source::Fields->new($name);
    if ($collect->native) {
        print "Package is native\n";
    }

=head1 DESCRIPTION

Lintian::Processable::Source::Fields provides an interface to package data for source
packages.  It implements data collection methods specific to source
packages.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
source packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 INSTANCE METHODS

=over 4

=item binaries

Returns a list of the binary and udeb packages listed in the
F<debian/control>.  Package names appear the same order in the
returned list as they do in the control file.

I<Note>: Package names that are not valid are silently ignored.

Needs-Info requirements for using I<binaries>: L<Same as binary_package_type|/binary_package_type (BINARY)>

=cut

sub binaries {
    my ($self) = @_;

    $self->load_debian_control
      unless scalar @{$self->binary_names};

    return @{ $self->binary_names };
}

=item binary_package_type (BINARY)

Returns package type based on value of the Package-Type (or if absent,
X-Package-Type) field.  If the field is omitted, the default value
"deb" is used.

If the BINARY is not a binary listed in the source packages
F<debian/control> file, this method return C<undef>.

Needs-Info requirements for using I<binary_package_type>: L<Same as binary_field|/binary_field (PACKAGE[, FIELD[, DEFAULT]])>

=cut

sub binary_package_type {
    my ($self, $name) = @_;

    unless (scalar keys %{$self->binaries_data}) {

        # we need the binary fields for this.
        $self->load_debian_control
          unless scalar keys %{$self->binary_fields};

        my %install;
        foreach my $packagename (keys %{ $self->binary_fields }) {

            my $type = $self->binary_field($packagename, 'Package-Type');

            $type //= $self->binary_field($packagename, 'XC-Package-Type');
            $type //= 'deb';

            $install{$packagename} = lc $type;
        }

        $self->binaries_data(\%install);
    }

    return $self->binaries_data->{$name};
}

=item source_field([FIELD[, DEFAULT]])

Returns the content of the field FIELD from source package paragraph
of the F<debian/control> file, or DEFAULT (defaulting to C<undef>) if
the field is not present.  Only the literal value of the field is
returned.

If FIELD is not given, return a hashref mapping field names to their
values (in this case DEFAULT is ignored).  This hashref should not be
modified.

NB: If a field from the "dsc" file itself is desired, please use
L<field> instead.

=cut

# NB: We don't say "same as _load_ctrl" in the above, because
# _load_ctrl has no POD and would not appear in the generated
# API-docs.
sub source_field {
    my ($self, $name) = @_;

    $self->load_debian_control
      unless scalar keys %{$self->source_fields};

    return $self->source_fields
      unless length $name;

    unless(scalar keys %{$self->source_legend}) {
        $self->source_legend->{lc $_} = $_ for keys %{$self->source_fields};
    }

    my $exact = $self->source_legend->{lc $name};
    return
      unless length $exact;

    return $self->source_fields->{$exact};
}

=item binary_field (PACKAGE[, FIELD[, DEFAULT]])

Returns the content of the field FIELD for the binary package PACKAGE
in the F<debian/control> file, or DEFAULT (defaulting to C<undef>) if
the field is not present.  Inheritance of field values from the source
section of the control file is not implemented.  Only the literal
value of the field is returned.

If FIELD is not given, return a hashref mapping field names to their
values (in this case, DEFAULT is ignored).  This hashref should not be
modified.

If PACKAGE is not a binary built from this source, this returns
DEFAULT.

=cut

# NB: We don't say "same as _load_ctrl" in the above, because
# _load_ctrl has no POD and would not appear in the generated
# API-docs.
sub binary_field {
    my ($self, $package, $name) = @_;

    $self->load_debian_control
      unless scalar keys %{$self->binary_fields};

    return
      unless length $package;

    my $per_package = $self->binary_fields->{$package};
    return
      unless defined $per_package;

    return $per_package
      unless length $name;

    unless(scalar keys %{$self->binary_legend}) {

        for my $binary (keys %{$self->binary_fields}) {
            $self->binary_legend->{$binary}{lc $_} = $_
              for keys %{$self->binary_fields->{$binary}};
        }
    }

    my $exact = $self->binary_legend->{$package}{lc $name};
    return
      unless length $exact;

    return $per_package->{$exact};
}

=item load_debian_control

=item binaries_data
=item binary_names

=item binary_fields
=item binary_legend

=item source_fields
=item source_legend

=cut

has binaries_data => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });
has binary_names => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has binary_fields => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });
has binary_legend => (is => 'rw', default => sub { {} });

has source_fields => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });
has source_legend => (is => 'rw', default => sub { {} });

sub load_debian_control {
    my ($self) = @_;

    # Load the fields from d/control
    my $dctrl = $self->patched->resolve_path('debian/control');
    return 0
      unless defined $dctrl && $dctrl->is_open_ok;

    my $bytes = path($dctrl->unpacked_path)->slurp;
    return 0
      unless valid_utf8($bytes);

    my $contents = decode_utf8($bytes);

    my @control_data;
    eval {@control_data = parse_dpkg_control_string($contents);};

    if ($@) {
        # If it is a syntax error, ignore it (we emit
        # syntax-error-in-control-file in this case via
        # control-file).
        die $@
          unless $@ =~ /syntax error/;

        return 0;
    }

    # In theory you can craft a package such that d/control is empty.
    my $source = shift @control_data;
    $self->source_fields($source);

    my %install;
    foreach my $paragraph (@control_data) {
        my $name = $paragraph->{'Package'};
        next
          unless defined $name && $name =~ m{\A $PKGNAME_REGEX \Z}xsm;
        $install{$name} = $paragraph;
        push(@{$self->binary_names}, $name);
    }

    $self->binary_fields(\%install);

    return 1;
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

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

use Lintian::Deb822::Parser qw(parse_dpkg_control_string);
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

=cut

sub binaries {
    my ($self) = @_;

    return keys %{$self->binary_fields};
}

=item binary_package_type (BINARY)

Returns package type based on value of the Package-Type (or if absent,
X-Package-Type) field.  If the field is omitted, the default value
"deb" is used.

If the BINARY is not a binary listed in the source packages
F<debian/control> file, this method return C<undef>.

=cut

sub binary_package_type {
    my ($self, $name) = @_;

    my $fields = $self->binary_fields->{$name};
    return
      unless defined $fields;

    my $type = $fields->value('Package-Type');

    $type //= $fields->value('XC-Package-Type');
    $type //= 'deb';

    return lc $type;
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

    return $self->source_fields
      unless length $name;

    return $self->source_fields->value($name);
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

    return
      unless length $package;

    my $per_package = $self->binary_fields->{$package};
    return
      unless defined $per_package;

    return $per_package
      unless length $name;

    return $per_package->value($name);
}

=item binary_fields
=item source_fields
=item debian_control_sections

=cut

has binary_fields => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @sections = @{$self->debian_control_sections};

        # in theory, one could craft a package in which d/control is empty
        shift @sections;

        my @named
          = grep { ($_->value('Package') // EMPTY) =~ m{\A $PKGNAME_REGEX \Z}x }
          @sections;

        my %indexed = map { $_->value('Package') => $_ } @named;

        return \%indexed;
    });

has source_fields => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @sections = @{$self->debian_control_sections};

        # in theory, one could craft a package in which d/control is empty
        my $source = shift @sections;

        return $source;
    });

has debian_control_sections => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $file = $self->patched->resolve_path('debian/control');
        return []
          unless defined $file;

        return []
          unless $file->is_valid_utf8;

        my $contents = $file->decoded_utf8;
        my $deb822 = Lintian::Deb822::File->new;

        my @sections;
        eval {@sections = $deb822->parse_string($contents);};

        if (length $@) {
            # If it is a syntax error, ignore it (we emit
            # syntax-error-in-control-file in this case via
            # control-file).
            die $@
              unless $@ =~ /syntax error/;

            return [];
        }

        return \@sections;
    });

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

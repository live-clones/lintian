# -*- perl -*-
# Lintian::Processable::Source::Relation -- interface to source package data collection

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

package Lintian::Processable::Source::Relation;

use strict;
use warnings;

use Carp qw(croak);

use Lintian::Relation;

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Source::Relation - Lintian interface to source package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'source', '/path/to/lab-entry');
    my $collect = Lintian::Processable::Source::Relation->new($name);
    if ($collect->native) {
        print "Package is native\n";
    }

=head1 DESCRIPTION

Lintian::Processable::Source::Relation provides an interface to package data for source
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

=item binary_relation (PACKAGE, FIELD)

Returns a L<Lintian::Relation> object for the specified FIELD in the
binary package PACKAGE in the F<debian/control> file.  FIELD should be
one of the possible relationship fields of a Debian package or one of
the following special values:

=over 4

=item all

The concatenation of Pre-Depends, Depends, Recommends, and Suggests.

=item strong

The concatenation of Pre-Depends and Depends.

=item weak

The concatenation of Recommends and Suggests.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (always satisfied and implies nothing).

Any substvars in F<debian/control> will be represented in the returned
relation as packages named after the substvar.

Needs-Info requirements for using I<binary_relation>: L<Same as binary_field|/binary_field (PACKAGE[, FIELD[, DEFAULT]])>

=item saved_binary_relations

=cut

has saved_binary_relations => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

my %special = (
    all    => [qw(pre-depends depends recommends suggests)],
    strong => [qw(pre-depends depends)],
    weak   => [qw(recommends suggests)]);

my %known = map { $_ => 1 }
  qw(pre-depends depends recommends suggests enhances breaks
  conflicts provides replaces);

sub binary_relation {
    my ($self, $package, $field) = @_;

    $field = lc $field;

    return $self->saved_binary_relations->{$package}{$field}
      if exists $self->saved_binary_relations->{$package}{$field};

    my $result;
    if ($special{$field}) {
        $result
          = Lintian::Relation->and(map { $self->binary_relation($package, $_) }
              @{ $special{$field} });

    } else {
        croak "unknown relation field $field"
          unless $known{$field};
        my $value = $self->binary_field($package, $field);
        $result = Lintian::Relation->new($value);
    }

    $self->saved_binary_relations->{$package}{$field} = $result;

    return $result;
}

=item relation (FIELD)

Returns a L<Lintian::Relation> object for the given build relationship
field FIELD.  In addition to the normal build relationship fields, the
following special field names are supported:

=over 4

=item build-depends-all

The concatenation of Build-Depends, Build-Depends-Arch and
Build-Depends-Indep.

=item build-conflicts-all

The concatenation of Build-Conflicts, Build-Conflicts-Arch and
Build-Conflicts-Indep.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (always satisfied and implies nothing).

=item saved_relation

=cut

has saved_relations => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

sub relation {
    my ($self, $field) = @_;

    $field = lc $field;

    my $relation = $self->saved_relations->{$field};
    unless (defined $relation) {

        if ($field =~ /^build-(depends|conflicts)-all$/) {
            my $type = $1;
            my @fields
              = ("build-$type", "build-$type-indep", "build-$type-arch");
            $relation
              = Lintian::Relation->and(map { $self->relation($_) } @fields);

        } elsif ($field =~ /^build-(depends|conflicts)(?:-(?:arch|indep))?$/) {
            my $value = $self->field($field);
            $relation = Lintian::Relation->new($value);

        } else {
            croak("unknown relation field $field");
        }

        $self->saved_relations->{$field} = $relation;
    }

    return $relation;
}

=item relation_noarch (FIELD)

The same as L</relation (FIELD)>, but ignores architecture
restrictions and build profile restrictions in the FIELD field.

=item saved_relations_noarch

=cut

has saved_relations_noarch => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

sub relation_noarch {
    my ($self, $field) = @_;

    $field = lc $field;

    my $relation = $self->saved_relations_noarch->{$field};
    unless (defined $relation) {

        $relation = $self->relation($field)->restriction_less;
        $self->saved_relations_noarch->{$field} = $relation;
    }

    return $relation;
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

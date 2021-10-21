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

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Source::Relation - Lintian interface to source package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'source', '/path/to/lab-entry');
    my $collect = Lintian::Processable::Source::Relation->new($name);
    if ($collect->native) {
        print encode_utf8("Package is native\n");
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

=item All

The concatenation of Pre-Depends, Depends, Recommends, and Suggests.

=item Strong

The concatenation of Pre-Depends and Depends.

=item Weak

The concatenation of Recommends and Suggests.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (present but satisfies nothing).

Any substvars in F<debian/control> will be represented in the returned
relation as packages named after the substvar.

=item saved_binary_relations

=cut

has saved_binary_relations => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

my %alias = (
    all    => [qw(Pre-Depends Depends Recommends Suggests)],
    strong => [qw(Pre-Depends Depends)],
    weak   => [qw(Recommends Suggests)]);

my %known = map { $_ => 1 }
  qw(pre-depends depends recommends suggests enhances breaks
  conflicts provides replaces);

sub binary_relation {
    my ($self, $package, $name) = @_;

    return undef
      unless length $name;

    my $lowercase = lc $name;

    return undef
      unless length $package;

    my $relation = $self->saved_binary_relations->{$package}{$lowercase};
    unless (defined $relation) {

        if (length $alias{$lowercase}) {
            $relation
              = Lintian::Relation->new->logical_and(
                map { $self->binary_relation($package, $_) }
                  @{ $alias{$lowercase} });

        } else {
            croak encode_utf8("unknown relation field $name")
              unless $known{$lowercase};

            my $value
              = $self->debian_control->installable_fields($package)
              ->value($name);
            $relation = Lintian::Relation->new->load($value);
        }

        $self->saved_binary_relations->{$package}{$lowercase} = $relation;
    }

    return $relation;
}

=item relation (FIELD)

Returns a L<Lintian::Relation> object for the given build relationship
field FIELD.  In addition to the normal build relationship fields, the
following special field names are supported:

=over 4

=item Build-Depends-All

The concatenation of Build-Depends, Build-Depends-Arch and
Build-Depends-Indep.

=item Build-Conflicts-All

The concatenation of Build-Conflicts, Build-Conflicts-Arch and
Build-Conflicts-Indep.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (present but satisfies nothing).

=item saved_relation

=cut

has saved_relations => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

sub relation {
    my ($self, $name) = @_;

    return undef
      unless length $name;

    my $lowercase = lc $name;

    my $relation = $self->saved_relations->{$lowercase};
    unless (defined $relation) {

        if ($name =~ /^Build-(Depends|Conflicts)-All$/i) {
            my $type = $1;
            my @fields
              = ("Build-$type", "Build-$type-Indep", "Build-$type-Arch");
            $relation
              = Lintian::Relation->new->logical_and(map { $self->relation($_) }
                  @fields);

        } elsif ($name =~ /^Build-(Depends|Conflicts)(?:-(?:Arch|Indep))?$/i){
            my $value = $self->fields->value($name);
            $relation = Lintian::Relation->new->load($value);

        } else {
            croak encode_utf8("unknown relation field $name");
        }

        $self->saved_relations->{$lowercase} = $relation;
    }

    return $relation;
}

=item relation_norestriction (FIELD)

The same as L</relation (FIELD)>, but ignores architecture
restrictions and build profile restrictions in the FIELD field.

=item saved_relations_norestriction

=cut

has saved_relations_norestriction => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

sub relation_norestriction {
    my ($self, $name) = @_;

    return undef
      unless length $name;

    my $lowercase = lc $name;

    my $relation = $self->saved_relations_norestriction->{$lowercase};
    unless (defined $relation) {

        $relation = $self->relation($name)->restriction_less;
        $self->saved_relations_norestriction->{$lowercase} = $relation;
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

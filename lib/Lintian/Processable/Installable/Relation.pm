# -*- perl -*-
# Lintian::Processable::Installable::Relation -- interface to binary package data collection

# Copyright © 2008, 2009 Russ Allbery
# Copyright © 2008 Frank Lichtenheld
# Copyright © 2012 Kees Cook
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

package Lintian::Processable::Installable::Relation;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Installable::Relation - Lintian interface to binary package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'binary', '/path/to/lab-entry');
    my $collect = Lintian::Processable::Installable::Relation->new($name);

=head1 DESCRIPTION

Lintian::Processable::Installable::Relation provides an interface to package data for binary
packages.  It implements data collection methods specific to binary
packages.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
binary packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

Native heuristics are only available in source packages.

=head1 INSTANCE METHODS

=over 4

=item relation (FIELD)

Returns a L<Lintian::Relation> object for the specified FIELD, which should
be one of the possible relationship fields of a Debian package or one of
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
object will be empty (always present and satisfies nothing).

=item saved_relations

=cut

has saved_relations => (
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

sub relation {
    my ($self, $name) = @_;

    my $lowercase = lc $name;

    my $relation = $self->saved_relations->{$lowercase};
    unless (defined $relation) {

        if (exists $alias{$lowercase}) {
            $relation
              = Lintian::Relation->new->logical_and(map { $self->relation($_) }
                  @{ $alias{$lowercase} });
        } else {
            croak encode_utf8("unknown relation field $name")
              unless $known{$lowercase};

            my $value = $self->fields->value($name);
            $relation = Lintian::Relation->new->load($value);
        }

        $self->saved_relations->{$lowercase} = $relation;
    }

    return $relation;
}

=back

=head1 AUTHOR

Originally written by Frank Lichtenheld <djpig@debian.org> for Lintian.
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

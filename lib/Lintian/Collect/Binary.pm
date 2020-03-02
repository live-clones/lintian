# -*- perl -*-
# Lintian::Collect::Binary -- interface to binary package data collection

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

package Lintian::Collect::Binary;

use strict;
use warnings;
use autodie;

use BerkeleyDB;
use Carp qw(croak);
use List::Util qw(any);
use MLDBM qw(BerkeleyDB::Btree Storable);
use Path::Tiny;

use Lintian::Deb822Parser qw(parse_dpkg_control);
use Lintian::Relation;
use Lintian::Util qw(open_gz get_file_checksum strip rstrip);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Collect::Binary - Lintian interface to binary package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'binary', '/path/to/lab-entry');
    my $collect = Lintian::Collect::Binary->new($name);

=head1 DESCRIPTION

Lintian::Collect::Binary provides an interface to package data for binary
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

=item strings (FILE)

Returns an open handle, which will read the data from coll/strings for
FILE.  If coll/strings did not collect any strings about FILE, this
returns an open read handle with no content.

Caller is responsible for closing the handle either way.

Needs-Info requirements for using I<strings>: strings

=cut

sub strings {
    my ($self, $file) = @_;

    my $real = path($self->groupdir)->child('strings')->child("${file}.gz")
      ->stringify;

    if (not -f $real) {
        open(my $fd, '<', '/dev/null');
        return $fd;
    }
    my $fd = open_gz($real);
    return $fd;
}

=item relation (FIELD)

Returns a L<Lintian::Relation> object for the specified FIELD, which should
be one of the possible relationship fields of a Debian package or one of
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

Needs-Info requirements for using I<relation>: L<Same as field|Lintian::Collect/field ([FIELD[, DEFAULT]])>

=cut

sub relation {
    my ($self, $field) = @_;
    $field = lc $field;
    return $self->{relation}{$field} if exists $self->{relation}{$field};

    my %special = (
        all    => [qw(pre-depends depends recommends suggests)],
        strong => [qw(pre-depends depends)],
        weak   => [qw(recommends suggests)]);
    my $result;
    if ($special{$field}) {
        $result = Lintian::Relation->and(map { $self->relation($_) }
              @{ $special{$field} });
    } else {
        my %known = map { $_ => 1 }
          qw(pre-depends depends recommends suggests enhances breaks
          conflicts provides replaces);
        croak("unknown relation field $field") unless $known{$field};
        my $value = $self->field($field);
        $result = Lintian::Relation->new($value);
    }
    $self->{relation}{$field} = $result;
    return $self->{relation}{$field};
}

=item is_pkg_class ([TYPE])

Returns a truth value if the package is the given TYPE of special
package.  TYPE can be one of "transitional", "debug" or "any-meta".
If omitted it defaults to "any-meta".  The semantics for these values
are:

=over 4

=item transitional

The package is (probably) a transitional package (e.g. it is probably
empty, just depend on stuff will eventually disappear.)

Guessed from package description.

=item any-meta

This package is (probably) some kind of meta or task package.  A meta
package is usually empty and just depend on stuff.  It will also
return a truth value for "tasks" (i.e. tasksel "tasks").

A transitional package will also match this.

Guessed from package description, section or package name.

=item debug

The package is (probably) a package containing debug symbols.

Guessed from the package name.

=item auto-generated

The package is (probably) a package generated automatically (e.g. a
dbgsym package)

Guessed from the "Auto-Built-Package" field.

=back

Needs-Info requirements for using I<is_pkg_class>: L<Same as field|Lintian::Collect/field ([FIELD[, DEFAULT]])>

=cut

{
    # Regexes to try against the package description to find metapackages or
    # transitional packages.
    my $METAPKG_REGEX= qr/meta[ -]?package|dummy|(?:dependency|empty) package/;

    sub is_pkg_class {
        my ($self, $pkg_class) = @_;
        my $desc = $self->field('description', '');
        $pkg_class //= 'any-meta';
        if ($pkg_class eq 'debug') {
            return 1 if $self->name =~ m/-dbg(?:sym)?/;
            return 0;
        }
        if ($pkg_class eq 'auto-generated') {
            return 1 if $self->field('auto-built-package');
            return 0;
        }
        return 1 if $desc =~ m/transitional package/;
        $desc = lc($desc);
        if ($pkg_class eq 'any-meta') {
            my ($section) = $self->field('section', '');
            return 1 if $desc =~ m/$METAPKG_REGEX/o;
            # Section "tasks" or "metapackages" qualifies as well
            return 1 if $section =~ m,(?:^|/)(?:tasks|metapackages)$,;
            return 1 if $self->name =~ m/^task-/;
        }
        return 0;
    }
}

=item is_non_free

Returns a truth value if the package appears to be non-free (based on
the section field; "non-free/*" and "restricted/*")

Needs-Info requirements for using I<is_non_free>: L</field ([FIELD[, DEFAULT]])>

=cut

sub is_non_free {
    my ($self) = @_;

    return 1
      if $self->field('section', 'main')
      =~ m,^(?:non-free|restricted|multiverse)/,;

    return 0;
}

=back

=head1 AUTHOR

Originally written by Frank Lichtenheld <djpig@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Relation>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

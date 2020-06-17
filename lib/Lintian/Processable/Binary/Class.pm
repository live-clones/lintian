# -*- perl -*-
# Lintian::Processable::Binary::Class -- interface to binary package data collection

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

package Lintian::Processable::Binary::Class;

use v5.20;
use warnings;
use utf8;
use autodie;

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Binary::Class - Lintian interface to binary package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'binary', '/path/to/lab-entry');
    my $collect = Lintian::Processable::Binary::Class->new($name);

=head1 DESCRIPTION

Lintian::Processable::Binary::Class provides an interface to package data for binary
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

=cut

# Regexes to try against the package description to find metapackages or
# transitional packages.
my $METAPKG_REGEX= qr/meta[ -]?package|dummy|(?:dependency|empty) package/;

sub is_pkg_class {
    my ($self, $class) = @_;

    $class //= 'any-meta';

    if ($class eq 'debug') {
        return 1
          if $self->name =~ m/-dbg(?:sym)?/;

        return 0;
    }

    if ($class eq 'auto-generated') {
        return 1
          if defined $self->field('Auto-Built-Package');

        return 0;
    }

    my $desc = $self->field('Description') // EMPTY;
    return 1
      if $desc =~ m/transitional package/;

    $desc = lc($desc);
    if ($class eq 'any-meta') {
        return 1
          if $desc =~ /$METAPKG_REGEX/;

        # Section "tasks" or "metapackages" qualifies as well
        my $section = $self->field('Section') // EMPTY;
        return 1
          if $section =~ m,(?:^|/)(?:tasks|metapackages)$,;

        return 1
          if $self->name =~ m/^task-/;
    }

    return 0;
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

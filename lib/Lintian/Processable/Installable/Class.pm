# -*- perl -*-
# Lintian::Processable::Installable::Class -- interface to binary package data collection

# Copyright © 2008, 2009 Russ Allbery
# Copyright © 2008 Frank Lichtenheld
# Copyright © 2012 Kees Cook
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Processable::Installable::Class;

use v5.20;
use warnings;
use utf8;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Installable::Class - Lintian interface to binary package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'binary', '/path/to/lab-entry');
    my $collect = Lintian::Processable::Installable::Class->new($name);

=head1 DESCRIPTION

Lintian::Processable::Installable::Class provides an interface to package data for binary
packages.

=head1 INSTANCE METHODS

=over 4

=item is_debug_package

The package probably contains only debug symbols.

=cut

sub is_debug_package {
    my ($self) = @_;

    return 1
      if $self->name =~ /-dbg(?:sym)?/;

    return 0;
}

=item is_auto_generated

The package was probably generated automatically.

=cut

sub is_auto_generated {
    my ($self) = @_;

    return 1
      if $self->fields->declares('Auto-Built-Package');

    return 0;
}

=item is_transitional

The package is probably transitional, i.e. it probably depends
 on stuff will eventually disappear.

=cut

sub is_transitional {
    my ($self) = @_;

    return 1
      if $self->fields->value('Description') =~ /transitional package/i;

    return 0;
}

=item is_meta_package

This package is probably some kind of meta or task package.  A meta
package is usually empty and just depend on stuff.  It also returns
a true value for "tasks" (i.e. tasksel "tasks").

=cut

sub is_meta_package {
    my ($self) = @_;

    return 1
      if $self->fields->value('Description')
      =~ /meta[ -]?package|(?:dependency|dummy|empty) package/i;

    # section "tasks" or "metapackages" qualifies too
    return 1
      if $self->fields->value('Section') =~ m{(?:^|/)(?:tasks|metapackages)$};

    return 1
      if $self->name =~ /^task-/;

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

# Check::Examples -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIES
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Examples;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has group_ships_examples => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @processables = $self->group->get_installables;

        # assume shipped examples if there is a package so named
        return 1
          if any { $_->name =~ m{-examples$} } @processables;

        my @shipped = map { @{$_->installed->sorted_list} } @processables;

        # Check each package for a directory (or symlink) called "examples".
        return 1
          if any { m{^usr/share/doc/(.+/)?examples/?$} } @shipped;

        return 0;
    }
);

sub visit_patched_files {
    my ($self, $item) = @_;

    # some installation files must be present; see Bug#972614
    $self->pointed_hint('package-does-not-install-examples', $item->pointer)
      if $item->basename eq 'examples'
      && $item->dirname !~ m{(?:^|/)(?:vendor|third_party)/}
      && $self->group->get_installables
      && !$self->group_ships_examples;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# desktop/gnome/gir/substvars -- lintian check script -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
# Copyright (C) 2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Desktop::Gnome::Gir::Substvars;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $DOLLAR => q{$};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $debian_control = $self->processable->debian_control;

    for my $installable ($debian_control->installables) {

        next
          unless $installable =~ m{ gir [\d.]+ - .* - [\d.]+ $}x;

        my $relation= $self->processable->binary_relation($installable, 'all');

        $self->pointed_hint(
            'gobject-introspection-package-missing-depends-on-gir-depends',
            $debian_control->item->pointer,$installable)
          unless $relation->satisfies($DOLLAR . '{gir:Depends}');
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

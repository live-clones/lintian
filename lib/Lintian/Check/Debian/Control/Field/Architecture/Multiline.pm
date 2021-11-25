# debian/control/field/architecture/multiline -- lintian check script -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Debian::Control::Field::Architecture::Multiline;

use v5.20;
use warnings;
use utf8;

use Lintian::Pointer::Item;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;

    for my $installable ($control->installables) {

        my $installable_fields = $control->installable_fields($installable);

        my $field = 'Architecture';

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item(
            $self->processable->patched->resolve_path('debian/control'));
        $pointer->position($installable_fields->position($field));

        $self->pointed_hint('multiline-architecture-field',
            $pointer, $field,"(in section for $installable)")
          if $installable_fields->value($field)=~ /\n./;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

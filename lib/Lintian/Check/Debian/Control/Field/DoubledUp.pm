# debian/control/field/doubled-up -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Field::DoubledUp;

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
    my $source_fields = $control->source_fields;

    # something like "Maintainer: Maintainer: bad field"
    my @doubled_up_source_fields
      = grep { $source_fields->value($_) =~ m{^ \Q$_\E \s* : }ix }
      $source_fields->names;

    for my $field (@doubled_up_source_fields) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item(
            $self->processable->patched->resolve_path('debian/control'));
        $pointer->position($source_fields->position($field));

        $self->pointed_hint('debian-control-repeats-field-name-in-value',
            $pointer, '(in section for source)', $field);
    }

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        # something like "Maintainer: Maintainer: bad field"
        my @doubled_up_installable_fields
          = grep { $installable_fields->value($_) =~ m{^ \Q$_\E \s* : }ix }
          $installable_fields->names;

        for my $field (@doubled_up_installable_fields) {

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item(
                $self->processable->patched->resolve_path('debian/control'));
            $pointer->position($installable_fields->position($field));

            $self->pointed_hint('debian-control-repeats-field-name-in-value',
                $pointer,"(in section for $installable)", $field);
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

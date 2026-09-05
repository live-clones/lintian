# debian/control/field/deprecated -- lintian check script -*- perl -*-
#
# Copyright (C) 2026 Nilesh Patra
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

package Lintian::Check::Debian::Control::Field::Deprecated;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    my $KNOWN_DEPRECATED_SOURCE_FIELDS
      = $self->data->load('common/deprecated-source-fields');

    for my $field ($source_fields->names) {
        my $control_item= $self->processable->debian_control->item;
        my $position = $source_fields->position($field);
        my $pointer = $control_item->pointer($position);

        # case-insensitive match
        $self->pointed_hint(
            'deprecated-debian-control-field',$pointer,
            '(in section for source)', $field
        )if $KNOWN_DEPRECATED_SOURCE_FIELDS->resembles($field);
    }

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        for my $field ($installable_fields->names) {
            my $control_item= $self->processable->debian_control->item;
            my $position = $installable_fields->position($field);
            my $pointer = $control_item->pointer($position);

            # case-insensitive match
            $self->pointed_hint(
                'deprecated-debian-control-field', $pointer,
                "(in section for $installable)", $field
            )if $KNOWN_DEPRECATED_SOURCE_FIELDS->resembles($field);
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

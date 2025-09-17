# debian/control/field/priority -- lintian check script -*- perl -*-
#
# Copyright (C) 2025 Nilesh Patra
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

package Lintian::Check::Debian::Control::Field::Priority;

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
    my $control_item = $self->processable->debian_control->item;
    my $position = $source_fields->position('Priority');
    my $pointer = $control_item->pointer($position);

    $self->pointed_hint('redundant-priority-optional-field', $pointer)
      if $source_fields->value('Priority') eq 'optional';

    # Priority may also be present in the binary stanza
    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);
        my $installable_position = $installable_fields->position('Priority');
        my $installable_pointer= $control_item->pointer($installable_position);
        $self->pointed_hint('redundant-priority-optional-field',
            $installable_pointer)
          if $installable_fields->value('Priority') eq 'optional';
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# debian/control/field/rules-requires-root -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Field::RulesRequiresRoot;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(first_value);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    my @r3_misspelled = grep { $_ ne 'Rules-Requires-Root' }
      grep { m{^ Rules? - Requires? - Roots? $}xi } $source_fields->names;

    for my $field (@r3_misspelled) {

        my $control_item= $self->processable->debian_control->item;
        my $position = $source_fields->position($field);
        my $pointer = $control_item->pointer($position);

        $self->pointed_hint('spelling-error-in-rules-requires-root',
            $pointer, $field);
    }

    my $control_item= $self->processable->debian_control->item;
    my $position = $source_fields->position('Rules-Requires-Root');
    my $pointer = $control_item->pointer($position);

    $self->pointed_hint('rules-require-root-explicitly', $pointer)
      if $source_fields->declares('Rules-Requires-Root')
      && $source_fields->value('Rules-Requires-Root') ne 'no';

    if (  !$source_fields->declares('Rules-Requires-Root')
        || $source_fields->value('Rules-Requires-Root') eq 'no') {

	$self->pointed_hint('rules-do-not-require-root', $pointer);

        for my $installable ($self->group->get_installables) {

            my $user_owned_item
              = first_value { $_->owner ne 'root' || $_->group ne 'root' }
            @{$installable->installed->sorted_list};

            next
              unless defined $user_owned_item;

            my $owner = $user_owned_item->owner;
            my $group = $user_owned_item->group;

            $self->pointed_hint('rules-silently-require-root',
                $pointer, $installable->name,
                "($owner:$group)", $user_owned_item->name);
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

# debian/control/field/rules-requires-root -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Field::RulesRequiresRoot;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(first_value);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $COLON => q{:};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    my @r3_misspelled = grep { $_ ne 'Rules-Requires-Root' }
      grep { m{^ Rules? - Requires? - Roots? $}xi } $source_fields->names;

    $self->hint('spelling-error-in-rules-requires-root',$_,
            $LEFT_SQUARE_BRACKET
          . 'debian/control:'
          . $source_fields->position($_)
          . $RIGHT_SQUARE_BRACKET)
      for @r3_misspelled;

    $self->hint('rules-do-not-require-root')
      if $source_fields->value('Rules-Requires-Root') eq 'no';

    $self->hint('rules-require-root-explicitly')
      if $source_fields->declares('Rules-Requires-Root')
      && $source_fields->value('Rules-Requires-Root') ne 'no';

    $self->hint('silent-on-rules-requiring-root')
      unless $source_fields->declares('Rules-Requires-Root');

    if (  !$source_fields->declares('Rules-Requires-Root')
        || $source_fields->value('Rules-Requires-Root') eq 'no') {

        for my $other ($self->group->get_binary_processables) {

            my $user_owned_item
              = first_value { $_->owner ne 'root' || $_->group ne 'root' }
            @{$other->installed->sorted_list};

            $self->hint(
                'rules-silently-require-root',
                $other->name,
                $user_owned_item->name,
                $LEFT_PARENTHESIS
                  . $user_owned_item->owner
                  . $COLON
                  . $user_owned_item->group
                  . $RIGHT_PARENTHESIS
            )if defined $user_owned_item;
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

# debian/control/prerequisitie/redundant -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Prerequisite::Redundant;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

const my $ARROW => q{->};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;

    # Make sure that a stronger dependency field doesn't satisfy any of
    # the elements of a weaker dependency field.  dpkg-gencontrol will
    # fix this up for us, but we want to check the source package
    # since dpkg-gencontrol may silently "fix" something that's a more
    # subtle bug.

    # ordered from stronger to weaker
    my @ordered_fields = qw(Pre-Depends Depends Recommends Suggests);

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        my @remaining_fields = @ordered_fields;

        for my $stronger (@ordered_fields) {

            shift @remaining_fields;

            next
              unless $control->installable_fields($installable)
              ->declares($stronger);

            my $relation
              = $self->processable->binary_relation($installable,$stronger);

            for my $weaker (@remaining_fields) {

                my @prerequisites = $control->installable_fields($installable)
                  ->trimmed_list($weaker, qr{\s*,\s*});

                for my $prerequisite (@prerequisites) {

                    $self->hint(
                        'redundant-installation-prerequisite',
                        $installable,
                        $weaker,
                        $ARROW,
                        $stronger,
                        $prerequisite,
                        "(in section for $installable)",
                        $LEFT_SQUARE_BRACKET
                          . 'debian/control:'
                          . $installable_fields->position($stronger)
                          . $RIGHT_SQUARE_BRACKET
                    )if $relation->satisfies($prerequisite);
                }
            }
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

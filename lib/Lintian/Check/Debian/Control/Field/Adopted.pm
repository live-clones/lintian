# debian/control/field/adopted -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Field::Adopted;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    my $KNOWN_SOURCE_FIELDS= $self->profile->load_data('common/source-fields');
    my $KNOWN_BINARY_FIELDS= $self->profile->load_data('fields/binary-fields');

    for my $field ($source_fields->names) {

        my ($marker, $bare) = split(qr{-}, $field, 2);

        next
          unless length $marker
          && length $bare;

        # case-insensitive match
        $self->hint('adopted-extended-field',$field,'(in section for source)',
                $LEFT_SQUARE_BRACKET
              . 'debian/control:'
              . $source_fields->position($field)
              . $RIGHT_SQUARE_BRACKET)
          if $marker =~ m{^ X }ix
          && $KNOWN_SOURCE_FIELDS->resembles($bare);
    }

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        for my $field ($installable_fields->names) {

            my ($marker, $bare) = split(qr{-}, $field, 2);

            next
              unless length $marker
              && length $bare;

            # case-insensitive match
            $self->hint(
                'adopted-extended-field',
                $field,
                "(in section for $installable)",
                $LEFT_SQUARE_BRACKET
                  . 'debian/control:'
                  . $installable_fields->position($field)
                  . $RIGHT_SQUARE_BRACKET
              )
              if $marker =~ m{^ X }ix
              && $KNOWN_BINARY_FIELDS->resembles($bare);
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

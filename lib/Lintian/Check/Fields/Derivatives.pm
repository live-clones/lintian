# fields/derivatives -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::Check::Fields::Derivatives;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $HYPHEN => q{-};

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $DERIVATIVE_FIELDS = $self->profile->load_data(
        'fields/derivative-fields',
        qr/\s*\~\~\s*/,
        sub {
            my ($regexp, $explanation) = split(/\s*\~\~\s*/, $_[1], 2);
            return {
                'regexp' => qr/$regexp/,
                'explanation' => $explanation,
            };
        });

    foreach my $field ($DERIVATIVE_FIELDS->all) {

        my $val = $processable->fields->value($field) || $HYPHEN;
        my $data = $DERIVATIVE_FIELDS->value($field);

        $self->hint('invalid-field-for-derivative',
            "$field: $val ($data->{'explanation'})")
          if $val !~ m/$data->{'regexp'}/;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

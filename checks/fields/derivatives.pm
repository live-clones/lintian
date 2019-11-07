# fields/derivatives -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
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

package Lintian::fields::derivatives;

use strict;
use warnings;
use autodie;

use Lintian::Data ();

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $DERIVATIVE_FIELDS = Lintian::Data->new(
    'fields/derivative-fields',
    qr/\s*\~\~\s*/,
    sub {
        my ($regexp, $explanation) = split(/\s*\~\~\s*/, $_[1], 2);
        return {
            'regexp' => qr/$regexp/,
            'explanation' => $explanation,
        };
    });

sub source {
    my ($self) = @_;

    my $info = $self->info;

    foreach my $field ($DERIVATIVE_FIELDS->all) {

        my $val = $info->field($field, '-');
        my $data = $DERIVATIVE_FIELDS->value($field);

        $self->tag('invalid-field-for-derivative',
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

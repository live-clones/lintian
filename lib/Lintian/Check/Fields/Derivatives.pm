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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Fields::Derivatives;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $HYPHEN => q{-};

use Moo;
use namespace::clean;

with 'Lintian::Check';

has DERIVATIVE_FIELDS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %fields;

        my $data= $self->data->load('fields/derivative-fields',qr/\s*\~\~\s*/);

        for my $key ($data->all) {

            my $value = $data->value($key);
            my ($regexp, $explanation) = split(/\s*\~\~\s*/, $value, 2);
            $fields{$key} = {
                'regexp' => qr/$regexp/,
                'explanation' => $explanation,
            };
        }

        return \%fields;
    }
);

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    for my $field (keys %{$self->DERIVATIVE_FIELDS}) {

        my $val = $processable->fields->value($field) || $HYPHEN;
        my $data = $self->DERIVATIVE_FIELDS->{$field};

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

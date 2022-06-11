# triggers -- lintian check script -*- perl -*-

# Copyright (C) 2017 Niels Thykier
# Copyright (C) 2021 Felix Lechner
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

package Lintian::Check::Triggers;

use v5.20;
use warnings;
use utf8;
use autodie qw(open);

use Const::Fast;
use List::SomeUtils qw(all);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

has TRIGGER_TYPES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %trigger_types;

        my $data
          = $self->data->load('triggers/trigger-types',qr{ \s* => \s* }x);
        for my $type ($data->all) {

            my $attributes  = $data->value($type);

            my %one_type;

            for my $pair (split(m{ \s* , \s* }x, $attributes)) {

                my ($flag, $setting) = split(m{ \s* = \s* }x, $pair, 2);
                $one_type{$flag} = $setting;
            }

            die encode_utf8(
"Invalid trigger-types: $type is defined as implicit-await but not await"
              )
              if $one_type{'implicit-await'}
              && !$one_type{await};

            $trigger_types{$type} = \%one_type;
        }

        return \%trigger_types;
    });

sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless $item->name eq 'triggers';

    my @lines = split(m{\n}, $item->decoded_utf8);

    my %positions_by_trigger_name;

    my $position = 1;
    while (defined(my $line = shift @lines)) {

        # trim both ends
        $line =~ s/^\s+|\s+$//g;

        next
          if $line =~ m/^(?:\s*)(?:#.*)?$/;

        my ($trigger_type, $trigger_name) = split($SPACE, $line, 2);
        next
          unless all { length } ($trigger_type, $trigger_name);

        $positions_by_trigger_name{$trigger_name} //= [];
        push(@{$positions_by_trigger_name{$trigger_name}}, $position);

        my $trigger_info = $self->TRIGGER_TYPES->{$trigger_type};
        if (!$trigger_info) {

            $self->pointed_hint('unknown-trigger', $item->pointer($position),
                $trigger_type);
            next;
        }

        $self->pointed_hint('uses-implicit-await-trigger',
            $item->pointer($position),
            $trigger_type)
          if $trigger_info->{'implicit-await'};

    } continue {
        ++$position;
    }

    my @duplicates= grep { @{$positions_by_trigger_name{$_}} > 1 }
      keys %positions_by_trigger_name;

    for my $trigger_name (@duplicates) {

        my $indicator
          = $LEFT_PARENTHESIS . 'lines'
          . $SPACE
          . join($SPACE,
            sort { $a <=> $b }@{$positions_by_trigger_name{$trigger_name}})
          . $RIGHT_PARENTHESIS;

        $self->pointed_hint('repeated-trigger-name', $item->pointer,
            $trigger_name, $indicator);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# fields/style -- lintian check script -*- perl -*-
#
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

package Lintian::Check::Fields::Style;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# the fields in d/control provide the values for many fields elsewhere
sub source {
    my ($self) = @_;

    my $debian_control = $self->processable->debian_control;
    my $control_item = $debian_control->item;

    # look at d/control source paragraph
    my $source_fields = $debian_control->source_fields;

    $self->check_style($source_fields, $control_item);

    for my $installable ($debian_control->installables) {

        # look at d/control installable paragraphs
        my $installable_fields
          = $debian_control->installable_fields($installable);

        $self->check_style($installable_fields, $control_item);
    }

    return;
}

sub check_style {
    my ($self, $fields, $item) = @_;

    for my $name ($fields->names) {

        # title-case the field name
        my $standard = lc $name;
        $standard =~ s/\b(\w)/\U$1/g;

        # capitalize up to three letters after an X, if followed by hyphen
        $standard =~ s/^(X[SBC]{1,3})-/\U$1-/i;

        my $position = $fields->position($name);
        my $pointer = $item->pointer($position);

        $self->pointed_hint('cute-field', $pointer, "$name vs $standard")
          unless $name eq $standard;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

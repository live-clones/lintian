# archive/non-free/autobuild -- lintian check script -*- perl -*-
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

package Lintian::Check::Archive::NonFree::Autobuild;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    return
      unless $self->processable->is_non_free;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    my $changes = $self->group->changes;

    # source-only upload
    if (defined $changes
        && $changes->fields->value('Architecture') eq 'source') {

        my $field = 'XS-Autobuild';

        my $control_item= $self->processable->debian_control->item;
        my $position = $source_fields->position($field);
        my $pointer = $control_item->pointer($position);

        $self->pointed_hint('source-only-upload-to-non-free-without-autobuild',
            $pointer, '(in the source paragraph)', $field)
          if !$source_fields->declares($field)
          || $source_fields->value($field) eq 'no';
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# languages/golang/built-using -- lintian check script -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
# Copyright (C) 2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
# Copyright (C) 2025 Maytham Alsudany <maytha8thedev@gmail.com>
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

package Lintian::Check::Languages::Golang::BuiltUsing;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    return
      unless $self->processable->relation('Build-Depends')
      ->satisfies('golang-go | golang-any');

    my $control = $self->processable->debian_control;

    for my $installable ($control->installables) {
        my $installable_fields= $control->installable_fields($installable);

        my $control_item= $self->processable->debian_control->item;
        my $position = $installable_fields->position('Package');

        $self->pointed_hint(
            'missing-static-built-using-field-for-golang-package',
            $control_item->pointer($position),
            "(in section for $installable)"
          )
          if $installable_fields->value('Static-Built-Using')
          !~ m{ \$ [{] misc:Static-Built-Using [}] }x
          && $installable_fields->value('Architecture') ne 'all';
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

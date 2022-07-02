# unpack -- lintian check script -*- perl -*-

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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Unpack;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    $self->hint('unpack-message-for-source', $_)
      for @{$processable->patched->unpack_messages};

    # empty for native
    $self->hint('unpack-message-for-orig', $_)
      for @{$processable->orig->unpack_messages};

    return;
}

sub installable {
    my ($self) = @_;

    my $processable = $self->processable;

    $self->hint('unpack-message-for-deb-data', $_)
      for @{$processable->installed->unpack_messages};

    $self->hint('unpack-message-for-deb-control', $_)
      for @{$processable->control->unpack_messages};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

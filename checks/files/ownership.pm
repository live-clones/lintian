# files/ownership -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::ownership;

use strict;
use warnings;
use autodie;

use Moo;

with('Lintian::Check');

sub files {
    my ($self, $file) = @_;

    if (
        !(
               $file->uid < 100
            || $file->uid == 65_534
            || ($file->uid >= 60_000 && $file->uid < 65_000))
        || !(
               $file->gid < 100
            || $file->gid == 65_534
            || ($file->gid >= 60_000 && $file->gid < 65_000))
    ) {
        $self->tag('wrong-file-owner-uid-or-gid', $file->name,
            $file->uid . '/' . $file->gid);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
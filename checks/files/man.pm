# files/man -- lintian check script -*- perl -*-

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

package Lintian::files::man;

use strict;
use warnings;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub files {
    my ($self, $file) = @_;

    return
      unless $file->name =~ m,^usr/share/man/\S+,;

    if ($self->type eq 'udeb') {
        $self->tag('manpage-in-udeb', $file->name);
    }

    if ($file->is_dir) {
        $self->tag('stray-directory-in-manpage-directory', $file->name)
          unless $file->name
          =~ m,^usr/(?:X11R6|share)/man/(?:[^/]+/)?(?:man\d/)?$,;

    } elsif ($file->is_file and ($file->operm & 0111)) {
        $self->tag('executable-manpage', $file->name);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

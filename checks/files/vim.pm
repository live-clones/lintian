# files/vim -- lintian check script -*- perl -*-

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

package Lintian::files::vim;

use strict;
use warnings;
use autodie;

use Moo;

with('Lintian::Check');

sub files {
    my ($self, $file) = @_;

    if ($file->name =~ m,^usr/share/vim/vim(?:current|\d{2})/([^/]++),){
        my $is_vimhelp = $1 eq 'doc' && $self->package =~ m,^vimhelp-\w++$,;
        my $is_vim = $self->source =~ m,vim,;

        $self->tag('vim-addon-within-vim-runtime-path', $file->name)
          unless $is_vim or $is_vimhelp;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

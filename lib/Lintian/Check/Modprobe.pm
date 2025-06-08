# modprobe -- lintian check script -*- perl -*-

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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Modprobe;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    if ($item->name =~ m{ ^(usr/lib|etc)/(modprobe|modules-load)\.d/. }x) {
        if ($item->is_dir) {
            $self->pointed_hint('directory-in-modprobe.d', $item->pointer);
        } elsif ($item->name !~ m{ [.]conf $}x) {
            $self->pointed_hint('non-conf-file-in-modprobe.d', $item->pointer);
        } else {
            my @obsolete = ($item->bytes =~ m{^ \s* ( install | remove ) }gmx);
            $self->pointed_hint('obsolete-command-in-modprobe.d-file',
                $item->pointer, $_)
              for uniq @obsolete;
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

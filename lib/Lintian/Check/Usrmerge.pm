# usrmerge -- lintian check script -*- perl -*-

# Copyright © 2016 Marco d'Itri
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

package Lintian::Check::Usrmerge;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->name =~ m{^(?:s?bin|lib(?:|[ox]?32|64))/};

    my $usrfile = $self->processable->installed->lookup("usr/$file");

    return
      unless $usrfile;

    return
      if $file->is_dir and $usrfile->is_dir;

    if ($file =~ m{^lib.+\.(?:so[\.0-9]*|a)$}) {
        $self->hint('library-in-root-and-usr', $file, $usrfile);
    } else {
        $self->hint('file-in-root-and-usr', $file, $usrfile);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

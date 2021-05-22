# files/desktop -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Files::Desktop;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $file) = @_;

    # .desktop files
    # People have placed them everywhere, but nowadays the
    # consensus seems to be to stick to the fd.org standard
    # drafts, which says that .desktop files intended for
    # menus should be placed in $XDG_DATA_DIRS/applications.
    # The default for $XDG_DATA_DIRS is
    # /usr/local/share/:/usr/share/, according to the
    # basedir-spec on fd.org. As distributor, we should only
    # allow /usr/share.

    $self->hint('desktop-file-in-wrong-dir', $file->name)
      if $file->name =~ m{^usr/share/gnome/apps/.*\.desktop$};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

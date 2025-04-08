# appimage -- lintian check script -*- perl -*-

# Copyright (C) 2025 Marc Leeman <m.leeman@televic.com>
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

package Lintian::Check::Files::AppimageCheck;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # Look for files with .AppImage extension or AppImage magic bytes
    $self->pointed_hint('package-installs-appimage', $item->pointer)
      if $item->name =~ /\.AppImage$/i;

    my $magic = $item->magic(3);
    $self->pointed_hint('package-installs-appimage', $item->pointer)
      if $magic eq "AI\x02";

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

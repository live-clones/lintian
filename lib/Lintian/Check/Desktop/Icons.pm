# desktop/icons -- lintian check script -*- perl -*-

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

package Lintian::Check::Desktop::Icons;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    if ($item->name =~ m{/icons/[^/]+/(\d+)x(\d+)/(?!animations/).*\.png$}){

        my $directory_width = $1;
        my $directory_height = $2;

        my $resolved = $item->resolve_path;

        if ($resolved && $resolved->file_type =~ m/,\s*(\d+)\s*x\s*(\d+)\s*,/){

            my $file_width = $1;
            my $file_height = $2;

            my $width_delta = abs($directory_width - $file_width);
            my $height_delta = abs($directory_height - $file_height);

            $self->pointed_hint('icon-size-and-directory-name-mismatch',
                $item->pointer, $file_width.'x'.$file_height)
              if $width_delta > 2 || $height_delta > 2;
        }
    }

    $self->pointed_hint('raster-image-in-scalable-directory', $item->pointer)
      if $item->is_file
      && $item->name =~ m{/icons/[^/]+/scalable/.*\.(?:png|xpm)$};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

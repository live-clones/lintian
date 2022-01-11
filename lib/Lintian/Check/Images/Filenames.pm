# images/filenames -- lintian check script -*- perl -*-

# Copyright © 2019 Felix Lechner
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

package Lintian::Check::Images::Filenames;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @image_formats = ({
        name => 'PNG',
        file_type => qr/^PNG image data/,
        good_name => sub { $_[0] =~ /\.(?:png|PNG)$/ }
    },
    {
        name => 'JPEG',
        file_type => qr/^JPEG image data/,
        good_name => sub { $_[0] =~ /\.(?:jpg|JPG|jpeg|JPEG)$/ }
    },
    {
        name => 'GIF',
        file_type => qr/^GIF image data/,
        good_name => sub { $_[0] =~ /\.(?:gif|GIF)$/ }
    },
    {
        name => 'TIFF',
        file_type => qr/^TIFF image data/,
        good_name => sub { $_[0] =~ /\.(?:tiff|TIFF|tif|TIF)$/ }
    },
    {
        name => 'XPM',
        file_type => qr/^X pixmap image/,
        good_name => sub { $_[0] =~ /\.(?:xpm|XPM)$/ }
    },
    {
        name => 'Netpbm',
        file_type => qr/^Netpbm image data/,
        good_name => sub { $_[0] =~ /\.(?:pbm|PBM|pgm|PGM|ppm|PPM|pnm|PNM)$/ }
    },
    {
        name => 'SVG',
        file_type => qr/^SVG Scalable Vector Graphics image/,
        good_name => sub { $_[0] =~ /\.(?:svg|SVG)$/ }
    },
);

# ICO format developed into a container and may contain PNG

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    my $our_format;

    for my $format (@image_formats) {

        if ($item->file_type =~ $format->{file_type}) {
            $our_format = $format;
            last;
        }
    }

    # not an image
    return
      unless $our_format;

    return
      if $our_format->{good_name}->($item->name);

    my $conflicting_format;

    my @other_formats = grep { $_ != $our_format } @image_formats;
    for my $format (@other_formats) {

        if ($format->{good_name}->($item->name)) {
            $conflicting_format = $format;
            last;
        }
    }

    if ($conflicting_format) {

        $self->pointed_hint('image-file-has-conflicting-name',
            $item->pointer, '(is ' . $our_format->{name} . ')')
          unless $our_format->{good_name}->($item->name);

    } else {
        $self->pointed_hint('image-file-has-unexpected-name',
            $item->pointer, '(is ' . $our_format->{name} . ')');
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

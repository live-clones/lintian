# files/x11 -- lintian check script -*- perl -*-

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

package Lintian::files::x11;

use strict;
use warnings;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has x11_font_dirs => (is => 'rwp', default => sub { {} });

sub files {
    my ($self, $file) = @_;

    # links to FHS locations are allowed
    if ($file->name =~ m,^usr/X11R6/, and not $file->is_symlink) {
        $self->tag('package-installs-file-to-usr-x11r6', $file->name);
    }

    # /usr/share/fonts/X11
    if ($file->name =~ m,^usr/share/fonts/X11/([^/]+)/\S+,) {

        my $dir = $1;
        if ($dir =~ /^(?:PEX|CID|Speedo|cyrillic)$/) {
            $self->tag('file-in-discouraged-x11-font-directory', $file->name);

        } elsif ($dir !~ /^(?:100dpi|75dpi|misc|Type1|encodings|util)$/) {
            $self->tag('file-in-unknown-x11-font-directory', $file->name);

        } elsif ($file->basename eq 'encodings.dir'
            or $file->basename =~ m{fonts\.(dir|scale|alias)}) {
            $self->tag('package-contains-compiled-font-file', $file->name);
        }

        if ($dir =~ /^(?:100dpi|75dpi|misc)$/) {
            $self->x11_font_dirs->{$dir}++;
        }
    }

    return;
}

sub breakdown {
    my ($self) = @_;

    # X11 bitmapped font directories under /usr/share/fonts/X11 in which we've
    # seen files.
    my %x11_font_dirs = %{$self->x11_font_dirs};

    # check for multiple DPIs in the same X11 bitmap font package.
    if ($x11_font_dirs{'100dpi'} and $x11_font_dirs{'75dpi'}) {
        $self->tag('package-contains-multiple-dpi-fonts');
    }
    if ($x11_font_dirs{misc} and keys(%x11_font_dirs) > 1) {
        $self->tag('package-mixes-misc-and-dpi-fonts');
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

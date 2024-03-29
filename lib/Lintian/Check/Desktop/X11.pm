# desktop/x11 -- lintian check script -*- perl -*-

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

package Lintian::Check::Desktop::X11;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has fontdirs => (is => 'rw', default => sub { {} });

sub visit_installed_files {
    my ($self, $item) = @_;

    # links to FHS locations are allowed
    $self->pointed_hint('package-installs-file-to-usr-x11r6', $item->pointer)
      if $item->name =~ m{^usr/X11R6/} && !$item->is_symlink;

    return
      if $item->is_dir;

    # /usr/share/fonts/X11
    my ($subdir) = ($item->name =~ m{^usr/share/fonts/X11/([^/]+)/\S+});
    if (defined $subdir) {

        $self->fontdirs->{$subdir}++
          if any { $subdir eq $_ } qw(100dpi 75dpi misc);

        if (any { $subdir eq $_ } qw(PEX CID Speedo cyrillic)) {
            $self->pointed_hint('file-in-discouraged-x11-font-directory',
                $item->pointer);

        } elsif (none { $subdir eq $_ }
            qw(100dpi 75dpi misc Type1 encodings util)) {
            $self->pointed_hint('file-in-unknown-x11-font-directory',
                $item->pointer);

        } elsif ($item->basename eq 'encodings.dir'
            or $item->basename =~ m{fonts\.(dir|scale|alias)}) {
            $self->pointed_hint('package-contains-compiled-font-file',
                $item->pointer);
        }
    }

    return;
}

sub installable {
    my ($self) = @_;

    # X11 font directories with files
    my %fontdirs = %{$self->fontdirs};

    # check for multiple DPIs in the same X11 bitmap font package.
    $self->hint('package-contains-multiple-dpi-fonts')
      if $fontdirs{'100dpi'} && $fontdirs{'75dpi'};

    $self->hint('package-mixes-misc-and-dpi-fonts')
      if $fontdirs{misc} && keys %fontdirs > 1;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

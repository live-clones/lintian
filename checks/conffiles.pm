# conffiles -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
# Copyright (C) 2000 Sean 'Shaleh' Perry
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

package Lintian::conffiles;

use strict;
use warnings;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub files {
    my ($self, $file) = @_;

    # files /etc must be conffiles, with some exceptions).
    $self->tag('file-in-etc-not-marked-as-conffile', $file)
      if $file->is_file
      && $file->name =~ m,^etc/,
      && !($self->info->is_conffile($file->name)
        || $file =~ m,/README$,
        || $file eq 'etc/init.d/skeleton'
        || $file eq 'etc/init.d/rc'
        || $file eq 'etc/init.d/rcS');

    return
      unless $self->info->is_conffile($file->name);

    $self->tag('conffile-has-bad-file-type', $file)
      unless $file->is_file;

    return;
}

sub binary {
    my ($self) = @_;

    my %count;

    for my $absolute ($self->info->conffiles) {

        # all paths should be absolute
        $self->tag('relative-conffile', $absolute)
          unless $absolute =~ m,^/,;

        # strip the leading slash
        my $relative = $absolute;
        $relative =~ s,^/++,,;

        $count{$relative} //= 0;
        $count{$relative}++;

        $self->tag('conffile-is-not-in-package', $relative)
          unless defined $self->info->index($relative);

        $self->tag('file-in-etc-rc.d-marked-as-conffile', $relative)
          if $relative =~ m,^etc/rc.\.d/,;

        if ($relative !~ m,^etc/,) {
            if ($relative =~ m,^usr/,) {
                $self->tag('file-in-usr-marked-as-conffile', $relative);

            } else {
                $self->tag('non-etc-file-marked-as-conffile', $relative);
            }
        }
    }

    for my $path (keys %count) {
        $self->tag('duplicate-conffile', $path)
          if $count{$path} > 1;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIÈS
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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

package Lintian::Check::DhMake;

use v5.20;
use warnings;
use utf8;

use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    $self->pointed_hint('readme-source-is-dh_make-template', $item->pointer)
      if $item->name eq 'debian/README.source'
      && $item->bytes
      =~ / \QYou WILL either need to modify or delete this file\E /isx;

    if (   $item->name =~ m{^debian/(README.source|copyright|rules|control)$}
        && $item->is_open_ok) {

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            next
              unless $line =~ m/(?<!")(FIX_?ME)(?!")/;

            my $placeholder = $1;

            $self->pointed_hint('file-contains-fixme-placeholder',
                $item->pointer($position), $placeholder);

        } continue {
            ++$position;
        }

        close $fd;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

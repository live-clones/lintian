# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 1999 Joey Hess
# Copyright © 2000 Sean 'Shaleh' Perry
# Copyright © 2002 Josip Rodin
# Copyright © 2007 Russ Allbery
# Copyright © 2013-2018 Bastien ROUCARIÈS
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    $self->hint('readme-source-is-dh_make-template')
      if $item->name eq 'debian/README.source'
      && $item->bytes
      =~ / \QYou WILL either need to modify or delete this file\E /isx;

    if (   $item->name =~ m{^debian/(README.source|copyright|rules|control)$}
        && $item->is_open_ok) {

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        while (my $line = <$fd>) {
            next unless $line =~ m/(?<!")(FIX_?ME)(?!")/;
            $self->hint('file-contains-fixme-placeholder',
                $item->name . ":$. $1");
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

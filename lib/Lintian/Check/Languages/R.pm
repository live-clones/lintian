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

package Lintian::Check::Languages::R;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $RDATA_MAGIC_LENGTH => 4;

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # Ensure we have a README.source for R data files
    if (   $item->basename =~ /\.(?:rda|Rda|rdata|Rdata|RData)$/
        && $item->is_open_ok
        && $item->file_info =~ /gzip compressed data/
        && !$self->processable->patched->resolve_path('debian/README.source')){

        open(my $fd, '<:gzip', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        read($fd, my $magic, $RDATA_MAGIC_LENGTH)
          or die encode_utf8('Cannot read from ' . $item->unpacked_path);

        close($fd);

        $self->hint('r-data-without-readme-source', $item->name)
          if $magic eq 'RDX2';
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

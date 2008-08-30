# Tags::ColonSeparated -- Perl tags functions for lintian
# $Id: Tags.pm 489 2005-09-17 00:06:30Z djpig $

# Copyright (C) 2005 Frank Lichtenheld <frank@lichtenheld.de>
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

package Tags::ColonSeparated;
use strict;
use warnings;

sub quote_char {
    my ( $char, @items ) = @_;

    foreach (@items) {
	s/\\/\\\\/go;
	s/\Q$char\E/\\$char/go;
    }

    return @items;
}

sub print_tag {
    my ( $pkg_info, $tag_info, $information ) = @_;

    my $extra = "@$information";

    print join(':', quote_char( ':',
				$tag_info->{type},
				$tag_info->{severity},
				$tag_info->{certainty},
				(exists($tag_info->{experimental}) ? 'X' : '').
				($tag_info->{overridden}{override} ? 'O' : ''),
				@{$pkg_info}{'pkg','version','arch','type'},
				$tag_info->{tag},
				$extra,
				$tag_info->{overridden}{override},
				))."\n";
}

1;


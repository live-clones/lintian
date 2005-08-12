# Copyright (C) 1998 Christian Schwarz
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

use strict;

# define hash for manuals
my %manual = (
	   'policy' => 'Policy Manual',
	   'devref' => 'Developers Reference',
	   'fhs' => 'FHS',
	   );

my %url;
open(REFS, "$ENV{'LINTIAN_ROOT'}/lib/manual_refs") or
    die("Could not open manual_refs: $!");
while(<REFS>) {
    chomp;
    next if (m/^\s*\#/);

    my ($key, $data) = split;
    $url{$key} = $data;
}
close(REFS);

1;

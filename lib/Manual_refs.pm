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

our %refs;

my $lib = defined $ENV{LINTIAN_ROOT} ?  "$ENV{LINTIAN_ROOT}/" : "";

open (REFS, '<', "${lib}lib/manual_refs")
    or die "Could not open manual_refs: $!";

while(<REFS>) {
    chomp;
    next if not m/^(.+?)::(.*?)::(.+?)::(.*?)$/;

    my ($man, $section, $title, $u) = split('::');
    $section = '0' if $section eq "";
    $refs{$man}{$section}{title} = $title;
    $refs{$man}{$section}{url} = $u;
}

close REFS;

1;

# vim: sw=4 sts=4 ts=4 et sr

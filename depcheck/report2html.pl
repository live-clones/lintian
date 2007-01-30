#!/usr/bin/perl -w

# Copyright (C) 1998 Richard Braakman
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

my %bugs;
if (my $buglist = shift) {
    open(BUGS, $buglist) or die($buglist);
    while (<BUGS>) {
	chop;
	my $bugline = $_;
	my @b;
	while ($bugline =~ s/^(\d+)\s//) {
	    push(@b, &make_bugref($1))
	}
	$bugs{$bugline} = join(", ", @b);
    }
    close(BUGS);
}

my $inmenu = 0;

while (<STDIN>) {
    chop;
    if (s/^\s+//) {
	my $brokendep = &quotehtml($_);
	my $bug = $bugs{$_};
	if (defined $bug) {
	    delete $bugs{$_};
	    $brokendep .= '  [' . $bug . ']';
	}
	print("  <LI>$brokendep\n");
    } elsif (m/^$/) {
	next;
    } else {
	if ($inmenu) {
	    print("</MENU>\n\n");
	}
	$_ = &quotehtml($_);
	print("<H2>$_</H2>\n");
	print("<MENU>\n");
	$inmenu = 1;
    }
}

if ($inmenu) {
    print("</MENU>\n");
}

exit 0;

# -----

sub make_bugref {
    my $bugnum = shift;
    my $bugdir = substr($bugnum, 0, 2);

    return "<A HREF=\"http://www.debian.org/Bugs/db/$bugdir/$bugnum.html\">"
	. "\#$bugnum</A>";
}

sub quotehtml {
    $_ = shift;
    s/&/\&amp;/g;
    s/</\&lt;/g;
    s/>/\&gt;/g;
    return $_;
}

#!/usr/bin/perl

# Create HTML pages describing the results of dependency-integrity checks
# over the Debian archive.
#
# Copyright (C) 1998 Richard Braakman
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

require './config';

@archs = ('i386', 'alpha', 'm68k', 'powerpc', 'sparc', 'arm', 'hurd-i386');

@logfiles = map { "$LOG_DIR/Depcheck-" . $_ } @archs;
system("savelog @logfiles >/dev/null") == 0
    or die("cannot rotate logfiles");

# this stuff is most likely broken
$BINARY = "$LINTIAN_ARCHIVEDIR/dists/$LINTIAN_DIST/main";
$DEPCHECKDIR = "$LINTIAN_ROOT/depcheck";
$DEPCHECK = "$DEPCHECKDIR/dependencies.py";

$ENV{'PYTHONPATH'} = $DEPCHECKDIR;

system("$DEPCHECK $BINARY/binary-i386/Packages >$LOG_DIR/Depcheck-i386") == 0
    or die("depcheck failed for i386 architecture");

for $arch (@archs) {
    next if $arch eq 'i386';

    system("$DEPCHECK $BINARY/binary-$arch/Packages $LOG_DIR/Depcheck-i386 >$LOG_DIR/Depcheck-$arch") == 0
	or die("depcheck failed for $arch architecture");
}

%bug_used = ();
%bugs = ();

open(BUGS, "$LINTIAN_ROOT/depcheck/buglist") or die("buglist");
while (<BUGS>) {
    chop;
    $bugline = $_;
    @b = ();
    while ($bugline =~ s/^(\d+)\s//) {
	push(@b, &make_bugref($1));
    }
    $bugs{$bugline} = join(", ", @b);
}
close(BUGS);

open(HTML, ">$HTML_TMP_DIR/depcheck.html") or die("depcheck.html");

print HTML <<EOT;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 2.0//EN">
<HTML>
<HEAD>
  <TITLE>Debian: Dependency integrity check for the main distribution</TITLE>
</HEAD>
<BODY>
<H1>Dependency checks</H1>
This page summarizes the results of a scan that checks the following
two bits of Debian policy:<P>
<UL>
<LI>From section 2.1.2: The main section<P>
    <blockquote>
    The packages in "main" must not require a package outside of
    "main" for compilation or execution (thus, the package may not
    declare a "Depends" or "Recommends" relationship on a non-main package).
    </blockquote><P>
<LI>From section 2.2: Priorities<P>
    <blockquote>
    Packages may not depend on packages with lower priority values.
    If this should happen, one of the priority values will have to be
    adapted.
    </blockquote><P>
</UL>

The scan also looks for packages in the "base" section that depend on
packages not in the "base" section, and for packages that depend on
packages in "oldlibs" that are not themselves in "oldlibs".<P>

The scan checks the Recommends, Depends, and Pre-Depends headers in
all cases.<P>
EOT

for $arch (@archs) {
    genarch($arch);
}

close(HTML);

for $bug (keys %bugs) {
    unless ($bug_used{$bug}) {
	print STDERR "Unused bugnumber: $bug\n";
    }
}

exit 0;

sub genarch {
    my $arch = shift;

    print HTML "<HR>\n";
    print HTML "<A NAME=$arch>\n";
    print HTML "<H2>Dependency check for the $arch architecture</H2>\n\n";

    print HTML "<P>This list was generated from the $arch Packages file,<BR>\n"
	. "dated: " . &filetime("$BINARY/binary-$arch/Packages") . ".\n";

    if ($arch ne 'i386') {
	print HTML "<P>It excludes the checks which were already " .
	    "reported for the i386 architecture.\n";
    }

    print HTML "\n";

    open(REPORT, "$LOG_DIR/Depcheck-$arch") or die("Depcheck-$arch");
    &genreport;
    close(REPORT);
}

sub genreport {
    my $inlist = 0;
    my $brokendep;
    my $bug;
    
    while (<REPORT>) {
	chop;
	if (s/^\s+//) {
	    $brokendep = $_;
	    $bug = $bugs{$brokendep};
	    if (defined $bug) {
		$bug_used{$brokendep} = 1;
		$brokendep = quotehtml($brokendep) . '  [' . $bug . ']';
	    } else {
		$brokendep = quotehtml($brokendep);
	    }
	    print(HTML "  <LI>$brokendep\n");
	} elsif (m/^$/) {
	    next;
	} else {
	    if ($inlist) {
		print(HTML "</UL>\n\n");
	    }
	    $_ = &quotehtml($_);
	    print(HTML "<H3>$_</H3>\n");
	    print(HTML "<UL>\n");
	    $inlist = 1;
	}
    }
    
    if ($inlist) {
	print(HTML "</UL>\n");
    }
}

sub make_bugref {
    my $bugnum = shift;
    my $bugdir = substr($bugnum, 0, 2);

    return "<A HREF=\"http://www.debian.org/Bugs/db/$bugdir/$bugnum.html\">"
	. "\#$bugnum</A>";
}

sub quotehtml {
    $_ = $_[0] . '';
    s/&/\&amp;/g;
    s/</\&lt;/g;
    s/>/\&gt;/g;
    return $_;
}

sub filetime {
    my $time = (stat(shift))[9]; # mtime
    return scalar(gmtime($time));
}

# Hey emacs! This is a -*- Perl -*- script!
# Read_taginfo -- Perl utility function to read Lintian's tag information

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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

my $LINTIAN_ROOT = $ENV{'LINTIAN_ROOT'} || '/usr/share/lintian';
my $debug = $ENV{'LINTIAN_DEBUG'} || 0;

use lib "$ENV{'LINTIAN_ROOT'}/lib";
use Util;
use Text_utils;
use Manual_refs;
use vars qw(%url); # from the above

use strict;

# define hash for manuals
my %manual = (
	      'policy' => 'Policy Manual',
	      'devref' => 'Developers Reference',
	      'fhs' => 'FHS',
	     );

srand;

# load information about checker scripts
sub read_tag_info {
    my ($type) = @_;

    my $dtml_convert;
    my %tag_info;
    if (defined $type && $type eq 'html') {
	$dtml_convert = \&dtml_to_html;
    } else {
	$dtml_convert = \&dtml_to_text;
    }

 #   $debug = 2;
    for my $f (<$LINTIAN_ROOT/checks/*.desc>) {
	print "N: Reading checker description file $f ...\n" if $debug >= 2;

	my @secs = read_dpkg_control($f);
	$secs[0]->{'check-script'} or fail("error in description file $f: `Check-Script:' not defined");

	for (my $i=1; $i<=$#secs; $i++) {
	    (my $tag = $secs[$i]->{'tag'}) or fail("error in description file $f: section $i does not have a `Tag:'");

	    my @foo = split_paragraphs($secs[$i]->{'info'});
	    if ($secs[$i]->{'ref'}) {
		push(@foo,"");
		push(@foo,format_ref($secs[$i]->{'ref'}));
	    }

	    if ($secs[$i]->{'experimental'}) {
		push(@foo,"");
		push(@foo,"Please note that this tag is marked Experimental, which "
		     . "means that the code that generates it is not as well tested "
		     . "as the rest of Lintian, and might still give surprising "
		     . "results.  Feel free to ignore Experimental tags that do not "
		     . "seem to make sense, though of course bug reports are always "
		     . "welcomed.");
	    }

	    $tag_info{$tag} = join("\n",&$dtml_convert(@foo));
	}
    }
    return \%tag_info;
}

sub format_ref {
    my ($ref) = @_;

    my @foo = split(/\s*,\s*/o,$ref);
    my $u;
    for ($u=0; $u<=$#foo; $u++) {
	if ($foo[$u] =~ m,^\s*(policy|devref|fhs)\s*([\d\.]+)?\s*$,oi) {
	    my ($man,$sec) = ($1,$2);

	    $foo[$u] = $manual{lc $man};

	    if ($sec =~ m,^\d+$,o) {
		$foo[$u] .= ", chapter $sec";
	    } elsif ($sec) {
		$foo[$u] .= ", section $sec";
	    }

	    if (exists $url{"$man-$sec"}) {
		$foo[$u] = "<a href=\"$url{\"$man-$sec\"}\">$foo[$u]</a>";
	    } elsif (exists $url{$man}) {
		$foo[$u] = "<a href=\"$url{$man}\">$foo[$u]</a>";
	    }
	} elsif ($foo[$u] =~ m,^\s*((?:ftp|https?)://[\S~-]+?/?)\s*$,i) {
	    $foo[$u] = "<a href=\"$1\">$1</a>";
	} elsif ($foo[$u] =~ m,\s*([\w_-]+\(\d+\w*\))\s*$,i) {
	    $foo[$u] = "the $foo[$u] manual page";
	}
    }
	
    if ($#foo+1 > 2) {
	$ref = sprintf "Refer to %s, and %s for details.",join(', ',splice(@foo,0,$#foo)),@foo;
    } elsif ($#foo+1 > 0) {
	$ref = sprintf "Refer to %s for details.",join(' and ',@foo);
    }

    return $ref;
}

1;

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

use strict;

srand;

our %refs; # from Manual_refs

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

	    if ($secs[$i]->{'severity'} and $secs[$i]->{'certainty'}) {
		push(@foo, "");
		push(@foo, "Severity: $secs[$i]->{'severity'};");
		push(@foo, "Certainty: $secs[$i]->{'certainty'}");
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

sub manual_ref {
    my ($man, $sub) = @_;
    my $numbered = ($sub =~ /[A-Z\d\.]+/) ? 1 : 0;
    my $chapter = ($sub =~ /^[\d]+$/) ? 1 : 0;
    my $appendix = ($sub =~ /^[A-Z]+$/) ? 1 : 0;

    return "" if not exists $refs{$man}{0};

    my $man_title = $refs{$man}{0}{title};
    my $man_url = $refs{$man}{0}{url};
    my $text = "<a href='$man_url'>$man_title</a>";

    my $div = '';
    $div = "section $sub " if $numbered;
    $div = "chapter $sub " if $chapter;
    $div = "appendix $sub " if $appendix;

    if (exists $refs{$man}{$sub}) {
        my $sub_title = $refs{$man}{$sub}{title};
        my $sub_url = $refs{$man}{$sub}{url};
        $text .= " $div(<a href='$sub_url'>$sub_title</a>)";
    }

    if (not $man_url) {
        my @arr = ( $text );
        $text = join('', dtml_to_text(@arr));
    }

    return $text;
}

sub format_ref {
    my ($header) = @_;
    my $text = '';
    my @list;

    foreach my $ref (split(/,\s?/, $header)) {
        if ($ref =~ /^([\w-]+)\s(.+)$/) {
            $text = manual_ref($1, $2);
        } elsif ($ref =~ /^([\w_-]+)\((\d)\)$/) {
            $text = "the <a href='http://manpages.debian.net/cgi-bin/".
                    "man.cgi?query=$1&sektion=$2'>$ref</a> manual page";
        } elsif ($ref =~ /^(?:ftp|https?):\/\//) {
            $text = "<a href='$ref'>$ref</a>";
        }
        push(@list, $text) if $text;
    }

    if ($#list >= 2) {
        $text = join(', ', splice(@list , 0, $#list));
        $text = "Refer to $text, and @list for details.";
    } elsif ($#list >= 0) {
        $text = join(' and ', @list);
        $text = "Refer to $text for details.";
    }

    return $text;
}

1;

# vim: sw=4 sts=4 ts=4 et sr

# Hey emacs! This is a -*- Perl -*- script!
# Text_utils -- Perl utility functions for lintian

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
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

use strict;

# requires wrap() function
use Text::Wrap;

# html_wrap -- word-wrap a paragaph.  The wrap() function from Text::Wrap
# is not suitable, because it chops words that are longer than the line
# length.
sub html_wrap {
    my ($lead, @text) = @_;
    my @words = split(' ', join(' ', @text));
    # subtract 1 to compensate for the lack of a space before the first word.
    my $ll = length($lead) - 1;
    my $cnt = 0;
    my $r = "";

    while ($cnt <= $#words) {
	if ($ll + 1 + length($words[$cnt]) > 76) {
	    if ($cnt == 0) {
		# We're at the start of a line, and word still does not
		# fit.  Don't wrap it.
		$r .= $lead . shift(@words) . "\n";
	    } else {
		# start new line
		$r .= $lead . join(' ', splice(@words, 0, $cnt)) . "\n";
		$ll = length($lead) - 1;
		$cnt = 0;
	    }
	} else {
	    $ll += 1 + length($words[$cnt]);
	    $cnt++;
	}
    }

    if ($#words >= 0) {
	# finish last line
	$r .= $lead . join(' ', @words) . "\n";
    }

    return $r;
}

# split_paragraphs -- splits a bunch of text lines into paragraphs.
# This function returns a list of paragraphs.
# Paragraphs are separated by empty lines. Each empty line is a
# paragraph. Furthermore, indented lines are considered a paragraph.
sub split_paragraphs {
    return "" unless (@_);

    my $t = join("\n",@_);

    my ($l,@o);
    while ($t) {
	$t =~ s/^\.\n/\n/o;
	# starts with space or empty line?
	if (($t =~ s/^([ \t][^\n]*)\n?//o) or ($t =~ s/^()\n//o)) {
	    #FLUSH;
	    if ($l) {
		$l =~ s/\s+/ /go;
		$l =~ s/^\s+//o;
		$l =~ s/\s+$//o;
		push(@o,$l);
		undef $l;
	    }
	    #
	    push(@o,$1);
	}
	# normal line?
	elsif ($t =~ s/^([^\n]*)\n?//o) {
	    $l .= "$1 ";
	}
	# what else can happen?
	else {
	    fail("internal error in wrap");
	}
    }
    #FLUSH;
    if ($l) {
	$l =~ s/\s+/ /go;
	$l =~ s/^\s+//o;
	$l =~ s/\s+$//o;
	push(@o,$l);
	undef $l;
    }
    #

    return @o;
}

sub dtml_to_html {
    my @o;

    my $pre=0;
    for $_ (@_) {
	s,\&maint\;,<a href=\"mailto:lintian-maint\@debian.org\">Lintian maintainer</a>,o; # "
	s,\&debdev\;,<a href=\"mailto:debian-devel\@lists.debian.org\">debian-devel</a>,o; # "

	# empty line?
	if (/^\s*$/o) {
	    if ($pre) {
		push(@o,"\n");
	    }
	}
	# preformatted line?
	elsif (/^\s/o) {
	    if (not $pre) {
		push(@o,"<pre>");
		$pre=1;
	    }
	    push(@o,"$_");
	}
	# normal line
	else {
	    if ($pre) {
		push(@o,"</pre>");
		$pre=0;
	    }
	    push(@o,"$_<p>\n");
	}
    }
    if ($pre) {
	push(@o,"</pre>");
	$pre=0;
    }

    return @o;
}

sub dtml_to_text {
    for $_ (@_) {
	# substitute Lintian &tags;
	s,&maint;,lintian-maint\@debian.org,go;
	s,&debdev;,debian-devel\@lists.debian.org,go;

	# substitute HTML <tags>
	s,<i>,&lt;,go;
	s,</i>,&gt;,go;
	s,<[^>]+>,,go;

	# substitute HTML &tags;
	s,&lt;,<,go;
	s,&gt;,>,go;
	s,&amp;,\&,go;

	# preformatted?
	if (not /^\s/o) {
	    # no.

	    s,\s\s+, ,go;
	    s,^ ,,o;
	    s, $,,o;
	}
    }

    return @_;
}

# wrap_paragraphs -- wrap paragraphs in dpkg/dselect style.
# indented lines are not wrapped but displayed "as is"
sub wrap_paragraphs {
    my $lead = shift;
    my $html = 0;

    if ($lead eq 'HTML') {
	$html = 1;
	$lead = shift;
    }

    my $o;
    for my $t (split_paragraphs(@_)) {
	# empty or indented line?
	if ($t =~ /^$/ or $t =~ /^\s/) {
	    $o .= "$lead$t\n";
	} else {
	    if ($html) {
		$o .= html_wrap($lead, "$t\n");
	    } else {
		$o .= wrap($lead, $lead, "$t\n");
	    }
	}
    }
    return $o;
}

1;

# Hey emacs! This is a -*- Perl -*- script!
# Lintian::Tag::TextUtil -- Perl utility functions for lintian

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Tag::TextUtil;

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);
our @EXPORT_OK= qw(split_paragraphs wrap_paragraphs dtml_to_html dtml_to_text);

# requires wrap() function
use Text::Wrap;

=head1 NAME

Lintian::Tag::TextUtil -- text utility functions related to tags

=head1 SYNOPSIS

 use Lintian::Tag::TextUtil;

=head1 DESCRIPTION

A class with text utilities.

=head1 INSTANCE METHODS

=over 4

=item html_wrap

=cut

# html_wrap -- word-wrap a paragraph.  The wrap() function from Text::Wrap
# is not suitable, because it chops words that are longer than the line
# length.
sub html_wrap {
    my ($lead, @text) = @_;
    my @words = split(' ', join(' ', @text));
    # subtract 1 to compensate for the lack of a space before the first word.
    my $ll = length($lead) - 1;
    my $cnt = 0;
    my $r = '';

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

=item split_paragraphs

=cut

# split_paragraphs -- splits a bunch of text lines into paragraphs.
# This function returns a list of paragraphs.
# Paragraphs are separated by empty lines. Each empty line is a
# paragraph. Furthermore, indented lines are considered a paragraph.
sub split_paragraphs {
    return '' unless (@_);

    my $t = join("\n",@_);

    my ($l,@o);
    while ($t) {
        $t =~ s/^\.\n/\n/;
        # starts with space or empty line?
        if (($t =~ s/^([ \t][^\n]*)\n?//) or ($t =~ s/^()\n//)) {
            #FLUSH;
            if ($l) {

                # trim both ends
                $l =~ s/^\s+|\s+$//g;

                $l =~ s/\s++/ /g;
                push(@o,$l);
                undef $l;
            }
            #
            push(@o,$1);
        }
        # normal line?
        elsif ($t =~ s/^([^\n]*)\n?//) {
            $l .= "$1 ";
        }
        # what else can happen?
        else {
            die 'internal error in wrap';
        }
    }
    #FLUSH;
    if ($l) {

        # trim both ends
        $l =~ s/^\s+|\s+$//g;

        $l =~ s/\s++/ /g;
        push(@o,$l);
        undef $l;
    }
    #

    return @o;
}

=item dtml_to_html

=cut

sub dtml_to_html {
    my @o;

    my $pre=0;
    for $_ (@_) {
        s{\&maint\;}
          {<a href=\"mailto:lintian-maint\@debian.org\">Lintian maintainer</a>}xsm;
        s{\&debdev\;}
          {<a href=\"mailto:debian-devel\@lists.debian.org\">debian-devel</a>}xsm;

        # empty line?
        if (/^\s*$/) {
            if ($pre) {
                push(@o,"\n");
            }
        }
        # preformatted line?
        elsif (/^\s/) {
            if (not $pre) {
                push(@o,'<pre>');
                $pre=1;
            }
            push(@o,$_);
        }
        # normal line
        else {
            if ($pre) {
                my $last = pop @o;
                $last =~ s,\n?$,</pre>\n,;
                push @o, $last;
                $pre=0;
            }
            push(@o,"<p>$_</p>\n");
        }
    }
    if ($pre) {
        my $last = pop @o;
        $last =~ s,\n?$,</pre>\n,;
        push @o, $last;
        $pre=0;
    }

    return @o;
}

=item dtml_to_text

=cut

sub dtml_to_text {
    for $_ (@_) {
        # substitute Lintian &tags;
        s,&maint;,lintian-maint\@debian.org,g;
        s,&debdev;,debian-devel\@lists.debian.org,g;

        # substitute HTML <tags>
        s,<i>,&lt;,g;
        s,</i>,&gt;,g;
        s,<[^>]+>,,g;

        # substitute HTML &tags;
        s,&lt;,<,g;
        s,&gt;,>,g;
        s,&amp;,\&,g;

        # preformatted?
        if (not /^\s/) {
            # no.

            s,\s\s+, ,g;
            s,^ ,,;
            s, $,,;
        }
    }

    return @_;
}

=item wrap_paragraphs

=cut

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
    # Tell Text::Wrap that very long "words" (e.g. URLs) should rather
    # "overflow" the column width than be broken into multiple lines.
    # (#719769)
    local $Text::Wrap::huge = 'overflow';
    for my $t (split_paragraphs(@_)) {
        # empty or indented line?
        if ($t eq '' or $t =~ /^\s/) {
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

=back

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

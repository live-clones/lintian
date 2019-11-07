# files/privacy-breach -- lintian check script -*- perl -*-

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

package Lintian::files::privacy_breach;

use strict;
use warnings;
use autodie;

use Lintian::SlidingWindow;
use Lintian::Util qw(strip);

use constant BLOCKSIZE => 16_384;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $PRIVACY_BREAKER_WEBSITES= Lintian::Data->new(
    'files/privacy-breaker-websites',
    qr/\s*\~\~/o,
    sub {
        my ($regex, $tag, $suggest) = split(/\s*\~\~\s*/, $_[1], 3);
        $tag = defined($tag) ? strip($tag) : '';
        if (length($tag) == 0) {
            $tag = $_[0];
        }
        my %ret = (
            'tag' => $tag,
            'regexp' => qr/$regex/xsm,
        );
        if (defined($suggest)) {
            $ret{'suggest'} = $suggest;
        }
        return \%ret;
    });

my $PRIVACY_BREAKER_FRAGMENTS= Lintian::Data->new(
    'files/privacy-breaker-fragments',
    qr/\s*\~\~/o,
    sub {
        my ($regex, $tag) = split(/\s*\~\~\s*/, $_[1], 2);
        return {
            'keyword' => $_[0],
            'regex' => qr/$regex/xsm,
            'tag' => $tag,
        };
    });

my $PRIVACY_BREAKER_TAG_ATTR= Lintian::Data->new(
    'files/privacy-breaker-tag-attr',
    qr/\s*\~\~\s*/o,
    sub {
        my ($keywords,$regex) = split(/\s*\~\~\s*/, $_[1], 2);
        $regex =~ s/&URL/(?:(?:ht|f)tps?:)?\/\/[^"\r\n]*/g;
        my @keywordlist;
        my @keywordsorraw = split(/\s*\|\|\s*/,$keywords);
        foreach my $keywordor (@keywordsorraw) {
            my @keywordsandraw = split(/\s*&&\s*/,$keywordor);
            push(@keywordlist, \@keywordsandraw);
        }
        return {
            'keywords' => \@keywordlist,
            'regex' => qr/$regex/xsm,
        };
    });

sub detect_privacy_breach {
    my ($self, $file) = @_;
    my %privacybreachhash;

    return
      unless $file->is_regular_file;

    my $fd = $file->open(':raw');

    my $sfd = Lintian::SlidingWindow->new($fd,sub { $_=lc($_); },BLOCKSIZE);

    while (my $block = $sfd->readwindow) {

        # strip comments
        for my $x (qw(<!--(?!\[if).*?--\s*> /\*(?!@cc_on).*?\*/)) {
            $block =~ s@$x@@gs;
        }

        # try generic fragment tagging
        foreach my $keyword ($PRIVACY_BREAKER_FRAGMENTS->all) {
            if(index($block,$keyword) > -1) {
                my $keyvalue = $PRIVACY_BREAKER_FRAGMENTS->value($keyword);
                my $regex = $keyvalue->{'regex'};
                if ($block =~ m{($regex)}) {
                    my $capture = $1;
                    my $breaker_tag = $keyvalue->{'tag'};
                    unless (exists $privacybreachhash{'tag-'.$breaker_tag}){
                        $privacybreachhash{'tag-'.$breaker_tag} = 1;
                        $self->tag($breaker_tag, $file->name,
                            "(choke on: $capture)");
                    }
                }
            }
        }
        for my $x (
            qw(src="http src="ftp src="// data-href="http data-href="ftp
            data-href="// codebase="http codebase="ftp codebase="// data="http
            data="ftp data="// poster="http poster="ftp poster="// <link @import)
        ) {
            next if index($block, $x) == -1;
            $self->detect_generic_privacy_breach($block,\%privacybreachhash,
                $file);
            last;
        }
    }

    close($fd);
    return;
}

# According to html norm src attribute is used by tags:
#
# audio(v5+), embed (v5+), iframe (v4), frame, img, input, script, source, track(v5), video (v5)
# Add other tags with src due to some javascript code:
# div due to div.js
# div data-href due to jquery
# css with @import
sub detect_generic_privacy_breach {
    my ($self, $block, $privacybreachhash, $file) = @_;
    my %matchedkeyword;

    # now check generic tag
  TYPE:
    foreach my $type ($PRIVACY_BREAKER_TAG_ATTR->all) {
        my $keyvalue = $PRIVACY_BREAKER_TAG_ATTR->value($type);
        my $keywords =  $keyvalue->{'keywords'};

        my $orblockok = 0;
      ORBLOCK:
        foreach my $keywordor (@$keywords) {
          ANDBLOCK:
            foreach my $keyword (@$keywordor) {
                my $thiskeyword = $matchedkeyword{$keyword};
                if(!defined($thiskeyword)) {
                    if(index($block,$keyword) > -1) {
                        $matchedkeyword{$keyword} = 1;
                        $orblockok = 1;
                    }else {
                        $matchedkeyword{$keyword} = 0;
                        $orblockok = 0;
                        next ORBLOCK;
                    }
                }
                if($matchedkeyword{$keyword} == 0) {
                    $orblockok = 0;
                    next ORBLOCK;
                }else {
                    $orblockok = 1;
                }
            }
            if($orblockok == 1) {
                last ORBLOCK;
            }
        }
        if($orblockok == 0) {
            next TYPE;
        }

        my $regex = $keyvalue->{'regex'};

        while($block=~m{$regex}g){
            $self->check_tag_url_privacy_breach($1, $2, $3,$privacybreachhash,
                $file);
        }
    }
    return;
}

sub is_localhost {
    my ($urlshort) = @_;
    if(    $urlshort =~ m!^(?:[^/]+@)?localhost(?:[:][^/]+)?/!i
        || $urlshort =~ m!^(?:[^/]+@)?::1(?:[:][^/]+)?/!i
        || $urlshort =~ m!^(?:[^/]+@)?127(?:\.\d{1,3}){3}(?:[:][^/]+)?/!i) {
        return 1;
    }else {
        return 0;
    }
}

sub check_tag_url_privacy_breach {
    my ($self, $fulltag, $tagattr, $url,$privacybreachhash, $file) = @_;
    my $website = $url;
    # detect also "^//" trick
    $website =~ s,^"?(?:(?:ht|f)tps?:)?//,,;
    $website =~ s/"?$//;

    if (is_localhost($website)){
        # do nothing ok
        return;
    }

    # reparse fulltag for rel
    if ($tagattr eq 'link') {
        my $rel = $fulltag;
        $rel =~ m,<link
                      (?:\s[^>]+)? \s+
                      rel="([^"\r\n]*)"
                      [^>]*
                      >,xismog;
        my $relcontent = $1;
        if (defined($relcontent)) {
            # See, for example, https://www.w3schools.com/tags/att_link_rel.asp
            my %allowed = (
                'alternate'         => 1, # #891301
                'author'            => 1, # #891301
                'bookmark'          => 1, # #746656
                'canonical'         => 1, # #762753
                'copyright'         => 1, # #902919
                'edituri'           => 1, # #902919
                'generator'         => 1, # #891301
                'generator-home'    => 1, # texinfo
                'help'              => 1, # #891301
                'license'           => 1, # #891301
                'next'              => 1, # #891301
                'prev'              => 1, # #891301
                'schema.dct'        => 1, # #736992
                'search'            => 1, # #891301
            );
            return if ($allowed{$relcontent});
            if ($relcontent eq 'alternate') {
                my $type = $fulltag;
                $type =~ m,<link
                      (?:\s[^>]+)? \s+
                      type="([^"\r\n]*)"
                      [^>]*
                      >,xismog;
                my $typecontent = $1;
                if($typecontent eq 'application/rdf+xml') {
                    # see #79991
                    return;
                }
            }
        }
    }

    # False positive
    # legal.xml file of gnome
    # could be replaced by a link to local file but not really a privacy breach
    if(    $file->basename eq 'legal.xml'
        && $tagattr eq 'link'
        && $website =~ m{^creativecommons.org/licenses/}) {
        return;
    }

    # In Mallard XML, <link> is a clickable anchor that will not be
    # followed automatically.
    if(    $file->basename =~ '.xml$'
        && $tagattr eq 'link'
        && $file->file_contents
        =~ qr{ xmlns="http://projectmallard\.org/1\.0/"}) {
        return;
    }

    # track well known site
    foreach my $breaker ($PRIVACY_BREAKER_WEBSITES->all) {
        my $value = $PRIVACY_BREAKER_WEBSITES->value($breaker);
        my $regex = $value->{'regexp'};
        if ($website =~ m{$regex}mxs) {
            unless (exists $privacybreachhash->{'tag-'.$breaker}) {
                my $tag =  $value->{'tag'};
                my $suggest = $value->{'suggest'} // '';
                $privacybreachhash->{'tag-'.$breaker}= 1;
                $self->tag($tag, $file, $suggest, "($url)");
            }
            # do not go to generic case
            return;
        }
    }

    # generic case
    unless (exists $privacybreachhash->{'tag-generic-'.$website}){
        $self->tag('privacy-breach-generic', $file->name, "[$fulltag] ($url)");
        $privacybreachhash->{'tag-generic-'.$website} = 1;
    }
    return;
}

sub files {
    my ($self, $file) = @_;

    # html/javascript
    if (   $file->is_file
        && $file->name =~ m,\.(?:x?html?\d?|js|xht|xml|css)$,i) {

        if(     $self->processable->pkg_src eq 'josm'
            and $file->basename eq 'defaultpresets.xml') {
            # false positive

        } else {
            $self->detect_privacy_breach($file);
        }
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

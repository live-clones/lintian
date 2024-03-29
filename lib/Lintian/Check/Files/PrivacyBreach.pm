# files/privacy-breach -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Files::PrivacyBreach;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::SlidingWindow;

const my $BLOCKSIZE => 16_384;
const my $EMPTY => q{};

const my $PRIVACY_BREAKER_WEBSITES_FIELDS => 3;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has PRIVACY_BREAKER_WEBSITES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %website;

        my $data
          = $self->data->load('files/privacy-breaker-websites',qr/\s*\~\~/);

        for my $key ($data->all) {

            my $value = $data->value($key);

            my ($pattern, $tag, $suggest)
              = split(/ \s* ~~ \s* /msx,
                $value,$PRIVACY_BREAKER_WEBSITES_FIELDS);

            $tag //= $EMPTY;

            # trim both ends
            $tag =~ s/^\s+|\s+$//g;

            $tag = $key
              unless length $tag;

            $website{$key} = {
                'tag' => $tag,
                'regexp' => qr/$pattern/xsm,
            };

            $website{$key}{'suggest'} = $suggest
              if defined $suggest;
        }

        return \%website;
    }
);

has PRIVACY_BREAKER_FRAGMENTS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %fragment;

        my $data
          = $self->data->load('files/privacy-breaker-fragments',qr/\s*\~\~/);

        for my $key ($data->all) {

            my $value = $data->value($key);

            my ($pattern, $tag) = split(/\s*\~\~\s*/, $value, 2);

            $fragment{$key} = {
                'keyword' => $key,
                'regex' => qr/$pattern/xsm,
                'tag' => $tag,
            };
        }

        return \%fragment;
    }
);

has PRIVACY_BREAKER_TAG_ATTR => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %attribute;

        my $data
          = $self->data->load('files/privacy-breaker-tag-attr',qr/\s*\~\~\s*/);

        for my $key ($data->all) {

            my $value = $data->value($key);

            my ($keywords,$pattern) = split(/\s*\~\~\s*/, $value, 2);

            $pattern =~ s/&URL/(?:(?:ht|f)tps?:)?\/\/[^"\r\n]*/g;

            my @keywordlist;

            my @keywordsorraw = split(/\s*\|\|\s*/,$keywords);

            for my $keywordor (@keywordsorraw) {
                my @keywordsandraw = split(/\s*&&\s*/,$keywordor);
                push(@keywordlist, \@keywordsandraw);
            }

            $attribute{$key} = {
                'keywords' => \@keywordlist,
                'regex' => qr/$pattern/xsm,
            };
        }

        return \%attribute;
    }
);

sub detect_privacy_breach {
    my ($self, $file) = @_;

    my %privacybreachhash;

    return
      unless $file->is_regular_file;

    open(my $fd, '<:raw', $file->unpacked_path)
      or die encode_utf8('Cannot open ' . $file->unpacked_path);

    my $sfd = Lintian::SlidingWindow->new;
    $sfd->handle($fd);
    $sfd->blocksize($BLOCKSIZE);
    $sfd->blocksub(sub { $_ = lc; });

    while (my $lowercase = $sfd->readwindow) {
        # strip comments
        for my $x (qw(<!--(?!\[if).*?--\s*> /\*(?!@cc_on).*?\*/)) {
            $lowercase =~ s/$x//gs;
        }

        # keep sorted; otherwise 'exists' below produces inconsistent output
        for my $keyword (sort keys %{$self->PRIVACY_BREAKER_FRAGMENTS}) {

            if ($lowercase =~ / \Q$keyword\E /msx) {
                my $keyvalue= $self->PRIVACY_BREAKER_FRAGMENTS->{$keyword};
                my $regex = $keyvalue->{'regex'};

                if ($lowercase =~ m{($regex)}) {
                    my $capture = $1;
                    my $breaker_tag = $keyvalue->{'tag'};

                    unless (exists $privacybreachhash{'tag-'.$breaker_tag}){

                        $privacybreachhash{'tag-'.$breaker_tag} = 1;

                        $self->pointed_hint($breaker_tag, $file->pointer,
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
            next
              unless $lowercase =~ / \Q$x\E /msx;

            $self->detect_generic_privacy_breach($lowercase,
                \%privacybreachhash,$file);

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
    for my $type (sort keys %{$self->PRIVACY_BREAKER_TAG_ATTR}) {
        my $keyvalue = $self->PRIVACY_BREAKER_TAG_ATTR->{$type};
        my $keywords =  $keyvalue->{'keywords'};

        my $orblockok = 0;
      ORBLOCK:
        for my $keywordor (@{$keywords}) {
          ANDBLOCK:
            for my $keyword (@{$keywordor}) {

                my $thiskeyword = $matchedkeyword{$keyword};
                if(!defined($thiskeyword)) {
                    if ($block =~ / \Q$keyword\E /msx) {
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
    if(    $urlshort =~ m{^(?:[^/]+@)?localhost(?:[:][^/]+)?/}i
        || $urlshort =~ m{^(?:[^/]+@)?::1(?:[:][^/]+)?/}i
        || $urlshort =~ m{^(?:[^/]+@)?127(?:\.\d{1,3}){3}(?:[:][^/]+)?/}i) {
        return 1;
    }else {
        return 0;
    }
}

sub check_tag_url_privacy_breach {
    my ($self, $fulltag, $tagattr, $url,$privacybreachhash, $file) = @_;

    my $website = $url;
    # detect also "^//" trick
    $website =~ s{^"?(?:(?:ht|f)tps?:)?//}{};
    $website =~ s/"?$//;

    if (is_localhost($website)){
        # do nothing ok
        return;
    }

    # reparse fulltag for rel
    if ($tagattr eq 'link') {

        my $rel = $fulltag;
        $rel =~ m{<link
                      (?:\s[^>]+)? \s+
                      rel="([^"\r\n]*)"
                      [^>]*
                      >}xismog;
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

            return
              if ($allowed{$relcontent});

            if ($relcontent eq 'alternate') {
                my $type = $fulltag;
                $type =~ m{<link
                      (?:\s[^>]+)? \s+
                      type="([^"\r\n]*)"
                      [^>]*
                      >}xismog;
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
        && $file->bytes=~ qr{ xmlns="http://projectmallard\.org/1\.0/"}) {

        return;
    }

    # track well known site
    for my $breaker (sort keys %{$self->PRIVACY_BREAKER_WEBSITES}) {

        my $value = $self->PRIVACY_BREAKER_WEBSITES->{$breaker};
        my $regex = $value->{'regexp'};

        if ($website =~ m{$regex}mxs) {

            unless (exists $privacybreachhash->{'tag-'.$breaker}) {

                my $tag =  $value->{'tag'};
                my $suggest = $value->{'suggest'} // $EMPTY;

                $privacybreachhash->{'tag-'.$breaker}= 1;
                $self->pointed_hint($tag, $file->pointer, $suggest, "($url)");
            }

            # do not go to generic case
            return;
        }
    }

    # generic case
    unless (exists $privacybreachhash->{'tag-generic-'.$website}){

        $self->pointed_hint('privacy-breach-generic', $file->pointer,
            "[$fulltag]","($url)");
        $privacybreachhash->{'tag-generic-'.$website} = 1;
    }

    return;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    # html/javascript
    if (   $file->is_file
        && $file->name =~ m/\.(?:x?html?\d?|js|xht|xml|css)$/i) {

        if(     $self->processable->source_name eq 'josm'
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

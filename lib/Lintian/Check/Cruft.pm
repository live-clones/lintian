# cruft -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIES
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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

package Lintian::Check::Cruft;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none);

const my $EMPTY => q{};
const my $ASTERISK => q{*};
const my $DOT => q{.};

const my $ITEM_NOT_FOUND => -1;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my %NVIDIA_LICENSE = (
    keywords => [qw{license intellectual retain property}],
    sentences =>[
'retain all intellectual property and proprietary rights in and to this software and related documentation'
    ]
);

my %NON_FREE_LICENSES = (
# first field is tag
# second field is a list of keywords in lower case
# third field are lower case sentences to match the license. Notes that space are normalized before and formatting removed
# fourth field is a regex to use to match the license, use lower case and [ ] for space.
# 5th field is a function to call if the field 2th to 5th match.
# (see dispatch table %LICENSE_CHECK_DISPATCH_TABLE

    # json license
    'license-problem-json-evil' => {
        keywords => [qw{software evil good}],
        sentences => ['software shall be used for good'],
        regex =>
qr{software [ ] shall [ ] be [ ] used [ ] for [ ] good [ ]? ,? [ ]? not [ ] evil}msx
    },
    # non free RFC old version
    'license-problem-non-free-RFC' => {
        keywords => [qw{document purpose translate language}],
        sentences => ['this document itself may not be modified in any way'],
        regex =>
qr/this [ ] document [ ] itself [ ] may [ ] not [ ] be [ ] modified [ ] in [ ] any [ ] way [ ]?, [ ]? such [ ] as [ ] by [ ] removing [ ] the [ ] copyright [ ] notice [ ] or [ ] references [ ] to [ ] .{0,256} [ ]? except [ ] as [ ] needed [ ] for [ ] the [ ] purpose [ ] of [ ] developing [ ] .{0,128} [ ]? in [ ] which [ ] case [ ] the [ ] procedures [ ] for [ ] copyrights [ ] defined [ ] in [ ] the [ ] .{0,128} [ ]? process [ ] must [ ] be [ ] followed[ ]?,[ ]? or [ ] as [ ] required [ ] to [ ] translate [ ] it [ ] into [ ] languages [ ]/msx,
        callsub => 'rfc_whitelist_filename'
    },
    'license-problem-non-free-RFC-BCP78' => {
        keywords => [qw{license document bcp restriction}],
        sentences => ['bcp 78'],
        regex =>
qr{this [ ] document [ ] is [ ] subject [ ] to [ ] (?:the [ ] rights [ ]?, [ ] licenses [ ] and [ ]restrictions [ ] contained [ ] in [ ])? bcp [ ] 78}msx,
        callsub => 'rfc_whitelist_filename'
    },
# check GFDL block - The ".{0,1024}"-part in the regex
# will contain the "no invariants etc."  part if
# it is a good use of the license.  We include it
# here to ensure that we do not emit a false positive
# if the "redeeming" part is in the next block
# keyword document is here in order to benefit for other license keyword and a shortcut for documentation
    'license-problem-gfdl-invariants' => {
        keywords => [qw{license document gnu copy documentation}],
        sentences => ['gnu free documentation license'],
        regex =>
qr/(?'rawcontextbefore'(?:(?:(?!a [ ] copy [ ] of [ ] the [ ] license [ ] is).){1024}|\A(?:(?!a [ ] copy [ ] of [ ] the [ ] license [ ] is).){0,1024}|(?:[ ] copy [ ] of [ ] the [ ] license [ ] is.{0,1024}?))) gnu [ ] free [ ] documentation [ ] license (?'rawgfdlsections'(?:(?!gnu [ ] free [ ] documentation [ ] license).){0,1024}?) (?:a [ ] copy [ ] of [ ] the [ ] license [ ] is|this [ ] document [ ] is [ ] distributed)/msx,
        callsub => 'check_gfdl_license_problem'
    },
    # php license
    'license-problem-php-license' => {
        keywords => [qw{www.php.net group\@php.net phpfoo conjunction php}],
        sentences => ['this product includes php'],
        regex => qr{php [ ] license [ ]?[,;][ ]? version [ ] 3(?:\.\d+)?}msx,
        callsub => 'php_source_whitelist'
    },
    'license-problem-bad-php-license' => {
        keywords => [qw{www.php.net add-on conjunction}],
        sentences => ['this product includes php'],
        regex => qr{php [ ] license [ ]?[,;][ ]? version [ ] 2(?:\.\d+)?}msx,
        callsub => 'php_source_whitelist'
    },
    # cc by nc sa note that " is replaced by [ ]
    'license-problem-cc-by-nc-sa' => {
        keywords => [qw{license by-nc-sa creativecommons.org}],
        sentences => [
            '://creativecommons.org/licenses/by-nc-sa',
            'under attribution-noncommercial'
        ],
        regex =>
qr{(?:license [ ] rdf:[^=:]+=[ ]* (?:ht|f)tps?://(?:[^/.]\.)??creativecommons\.org/licenses/by-nc-sa/\d+(?:\.\d+)?(?:/[[:alpha:]]+)?/? [ ]* >|available [ ] under [ ] attribution-noncommercial)}msx
    },
    # not really a license but warn it: visual c++ generated file
    'source-contains-autogenerated-visual-c++-file' => {
        keywords => [qw{microsoft visual generated}],
        sentences => ['microsoft visual c++ generated'],
        regex =>
qr{microsoft [ ] visual [ ] c[+][+] [ ] generated (?![ ] by [ ] freeze\.py)}msx
    },
    # not really a license but warn about it: gperf generated file
    'source-contains-autogenerated-gperf-data' => {
        keywords => [qw{code produced gperf version}],
        sentences => ['code produced by gperf version'],
        regex =>
          qr{code [ ] produced [ ] by [ ] gperf [ ] version [ ] \d+\.\d+}msx
    },
    # warn about copy of ieee-data
    'source-contains-data-from-ieee-data-oui-db' => {
        keywords => [qw{struck scitex racore}],
        sentences => ['dr. b. struck'],
        regex => qr{dr. [ ] b. [ ] struck}msx
    },
    # warn about unicode license for utf for convert utf
    'license-problem-convert-utf-code' => {
        keywords => [qw{fall-through bytestowrite utf-8}],
        sentences => ['the fall-through switches in utf-8 reading'],
        regex =>
qr{the [ ] fall-through [ ] switches [ ] in [ ] utf-8 [ ] reading [ ] code [ ] save}msx
    }
);

# get usual data about admissible/not admissible GFDL invariant part of license
has GFDL_FRAGMENTS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %gfdl_fragments;

        my $data = $self->data->load('cruft/gfdl-license-fragments-checks',
            qr/\s*\~\~\s*/);

        for my $gfdlsectionsregex ($data->all) {

            my $secondpart = $data->value($gfdlsectionsregex);

            # allow empty parameters
            $secondpart //= $EMPTY;
            my ($acceptonlyinfile,$applytag)
              = split(/\s*\~\~\s*/, $secondpart, 2);

            $acceptonlyinfile //= $EMPTY;
            $applytag //= $EMPTY;

            # trim both ends
            $acceptonlyinfile =~ s/^\s+|\s+$//g;
            $applytag =~ s/^\s+|\s+$//g;

            # accept all files if empty
            $acceptonlyinfile ||= $DOT . $ASTERISK;

            my %ret = (
                'gfdlsectionsregex'   => qr/$gfdlsectionsregex/xis,
                'acceptonlyinfile' => qr/$acceptonlyinfile/xs,
            );

            $ret{'tag'} = $applytag
              if length $applytag;

            $gfdl_fragments{$gfdlsectionsregex} = \%ret;
        }

        return \%gfdl_fragments;
    }
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # license string in debian/changelog are probably just change
    # Ignore these strings in d/README.{Debian,source}.  If they
    # appear there it is probably just "file XXX got removed
    # because of license Y".
    $self->full_text_check($item)
      unless $item->name eq 'debian/changelog'
      && $item->name eq 'debian/README.Debian'
      && $item->name eq 'debian/README.source';

    return;
}

# do basic license check against well known offender
# note that it does not replace licensecheck(1)
# and is only used for autoreject by ftp-master
sub full_text_check {
    my ($self, $item) = @_;

    my $contents = $item->decoded_utf8;
    return
      unless length $contents;

    my $lowercase = lc($contents);
    my $clean = clean_text($lowercase);

    # Check for non-distributable files - this
    # applies even to non-free, as we still need
    # permission to distribute those.
    # nvdia opencv infamous license
    return
      if $self->check_for_single_bad_license($item, $lowercase, $clean,
        'license-problem-nvidia-intellectual',
        \%NVIDIA_LICENSE);

    unless ($self->processable->is_non_free) {

        for my $tag_name (keys %NON_FREE_LICENSES) {

            return
              if $self->check_for_single_bad_license($item, $lowercase, $clean,
                $tag_name, $NON_FREE_LICENSES{$tag_name});
        }
    }

    # check javascript in html file
    if ($item->basename =~ /\.(?:x?html?\d?|xht)$/i) {

        my $blockscript = $lowercase;
        my $indexscript;

        while (
            ($indexscript = index($blockscript, '<script')) > $ITEM_NOT_FOUND){

            $blockscript = substr($blockscript,$indexscript);

            # sourced script ok
            if ($blockscript =~ m{\A<script\s+[^>]*?src="[^"]+?"[^>]*?>}sm) {

                $blockscript = substr($blockscript,$+[0]);
                next;
            }

            # extract script
            if ($blockscript =~ m{<script[^>]*?>(.*?)</script>}sm) {

                $blockscript = substr($blockscript,$+[0]);

                my $lcscript = $1;

                # check if js script is minified
                my $firstline = $EMPTY;
                for my $line (split /\n/, $lcscript) {

                    if ($line =~ /^\s*$/) {
                        next;

                    } else {
                        $firstline = $line;
                        last;
                    }
                }

                if ($firstline
                    =~ m/.{0,20}((?:\bcopyright\b|[\(]c[\)]\s*\w|\N{COPYRIGHT SIGN}).{0,50})/
                ){

                    my $extract = $1;
                    $extract =~ s/^\s+|\s+$//g;

                    $self->pointed_hint(
                        'embedded-script-includes-copyright-statement',
                        $item->pointer,'extract of copyright statement:',
                        $extract);
                }

                # clean up jslint craps line
                my $cleaned = $lcscript;
                $cleaned =~ s{^\s*/[*][^\n]*[*]/\s*$}{}gm;
                $cleaned =~ s{^\s*//[^\n]*$}{}gm;
                $cleaned =~ s/^\s+//gm;

                # strip indentation
                $cleaned =~ s/^\s+//mg;
                $cleaned = _strip_c_comments($cleaned);
                # strip empty line
                $cleaned =~ s/^\s*\n//mg;
                # remove last \n
                $cleaned =~ s/\n\Z//m;

# detect browserified javascript (comment are removed here and code is stripped)
                my $contiguous = $cleaned;
                $contiguous =~ s/\n/ /msg;

                # get browserified regexp
                my $BROWSERIFY_REGEX
                  = $self->data->load('cruft/browserify-regex',qr/\s*\~\~\s*/);

                for my $condition ($BROWSERIFY_REGEX->all) {

                    my $pattern = $BROWSERIFY_REGEX->value($condition);
                    if ($contiguous =~ m{$pattern}msx) {

                        my $extra= (defined $1) ? 'code fragment:'.$1 : $EMPTY;
                        $self->pointed_hint(
                            'source-contains-browserified-javascript',
                            $item->pointer, $extra);

                        last;
                    }
                }

                next;
            }

            last;
        }
    }

    # check if file is javascript but not minified
    my $isjsfile = ($item->name =~ m/\.js$/) ? 1 : 0;
    if ($isjsfile) {
        my $minjsregexp
          = qr/(?i)[-._](?:compiled|compressed|lite|min|pack(?:ed)?|prod|umd|yc)\.js$/;
        $isjsfile = ($item->name =~ m{$minjsregexp}) ? 0 : 1;
    }

    if ($isjsfile) {
        # exception sphinx documentation
        if ($item->basename eq 'searchindex.js') {
            if ($lowercase =~ m/\A\s*search\.setindex\s* \s* \(\s*\{/xms) {

                $self->pointed_hint(
                    'source-contains-prebuilt-sphinx-documentation',
                    $item->parent_dir->pointer);
                return;
            }
        }

        if ($item->basename eq 'search_index.js') {
            if ($lowercase =~ m/\A\s*var\s*search_index\s*=/xms) {

                $self->pointed_hint(
                    'source-contains-prebuilt-pandoc-documentation',
                    $item->parent_dir->pointer);
                return;
            }
        }
        # false positive in dx package at least
        elsif ($item->basename eq 'srchidx.js') {

            return
              if $lowercase=~ m/\A\s*profiles \s* = \s* new \s* Array\s*\(/xms;
        }
        # https://github.com/rafaelp/css_browser_selector is actually the
        # original source. (#874381)
        elsif ($lowercase =~ m/css_browser_selector\(/) {

            return;
        }
        # Avoid false-positives in Jush's syntax highlighting definition files.
        elsif ($lowercase =~ m/jush\.tr\./) {

            return;
        }

        # now search hidden minified

        # clean up jslint craps line
        my $cleaned = $lowercase;
        $cleaned =~ s{^\s*/[*][^\n]*[*]/\s*$}{}gm;
        $cleaned =~ s{^\s*//[^\n]*$}{}gm;
        $cleaned =~ s/^\s+//gm;

        # strip indentation
        $cleaned =~ s/^\s+//mg;
        $cleaned = _strip_c_comments($cleaned);
        # strip empty line
        $cleaned =~ s/^\s*\n//mg;
        # remove last \n
        $cleaned =~ s/\n\Z//m;

# detect browserified javascript (comment are removed here and code is stripped)
        my $contiguous = $cleaned;
        $contiguous =~ s/\n/ /msg;

        # get browserified regexp
        my $BROWSERIFY_REGEX
          = $self->data->load('cruft/browserify-regex',qr/\s*\~\~\s*/);

        for my $condition ($BROWSERIFY_REGEX->all) {

            my $pattern = $BROWSERIFY_REGEX->value($condition);
            if ($contiguous =~ m{$pattern}msx) {

                my $extra = (defined $1) ? 'code fragment:'.$1 : $EMPTY;
                $self->pointed_hint('source-contains-browserified-javascript',
                    $item->pointer, $extra);

                last;
            }
        }
    }

    # search link rel header
    if ($lowercase =~ / \Q rel="copyright" \E /msx) {

        my $href = $lowercase;
        $href =~ m{<link \s+
                  rel="copyright" \s+
                  href="([^"]+)" \s*/? \s*>}xmsi;

        my $url = $1 // $EMPTY;

        $self->pointed_hint('license-problem-cc-by-nc-sa', $item->pointer)
          if $url =~ m{^https?://creativecommons.org/licenses/by-nc-sa/};
    }

    return;
}

# strip C comment
# warning block is at more 8192 char in order to be too slow
# and in order to avoid regex recursion
sub _strip_c_comments {
    my ($lowercase) = @_;

    # from perl faq strip comments
    $lowercase =~ s{
                # Strip /* */ comments
                /\* [^*]*+ \*++ (?: [^/*][^*]*+\*++ ) */
                # Strip // comments (C++ style)
                |  // (?: [^\\] | [^\n][\n]? )*? (?=\n)
                |  (
                    # Keep "/* */" (etc) as is
                    "(?: \\. | [^"\\]++)*"
                    # Keep '/**/' (etc) as is
                    | '(?: \\. | [^'\\]++)*'
                    # Keep anything else
                    | .[^/"'\\]*+
                   )
               }{defined $1 ? $1 : ""}xgse;

    return $lowercase;
}

# return True in case of license problem
sub check_gfdl_license_problem {
    my ($self, $item, $tag_name, %matchedhash) = @_;

    my $rawgfdlsections  = $matchedhash{rawgfdlsections}  || $EMPTY;
    my $rawcontextbefore = $matchedhash{rawcontextbefore} || $EMPTY;

    # strip punctuation
    my $gfdlsections  = _strip_punct($rawgfdlsections);
    my $contextbefore = _strip_punct($rawcontextbefore);

    # remove line number at beginning of line
    # see krusader/1:2.4.0~beta3-2/doc/en_US/advanced-functions.docbook/
    $gfdlsections =~ s{[ ]\d+[ ]}{ }gxsmo;
    $gfdlsections =~ s{^\d+[ ]}{ }xsmo;
    $gfdlsections =~ s{[ ]\d+$}{ }xsmo;
    $gfdlsections =~ s{[ ]+}{ }xsmo;

    # remove classical and without meaning part of
    # matched string
    my $oldgfdlsections;
    do {
        $oldgfdlsections = $gfdlsections;
        $gfdlsections =~ s{ \A \(?[ ]? g?fdl [ ]?\)?[ ]? [,\.;]?[ ]?}{}xsmo;
        $gfdlsections =~ s{ \A (?:either[ ])?
                           version [ ] \d+(?:\.\d+)? [ ]?}{}xsmo;
        $gfdlsections =~ s{ \A of [ ] the [ ] license [ ]?[,\.;][ ]?}{}xsmo;
        $gfdlsections=~ s{ \A or (?:[ ]\(?[ ]? at [ ] your [ ] option [ ]?\)?)?
                           [ ] any [ ] later [ ] version[ ]?}{}xsmo;
        $gfdlsections =~ s{ \A (as[ ])? published [ ] by [ ]
                           the [ ] free [ ] software [ ] foundation[ ]?}{}xsmo;
        $gfdlsections =~ s{\(?[ ]? fsf [ ]?\)?[ ]?}{}xsmo;
        $gfdlsections =~ s{\A [ ]? [,\.;]? [ ]?}{}xsmo;
        $gfdlsections =~ s{[ ]? [,\.]? [ ]?\Z}{}xsmo;
    } while ($oldgfdlsections ne $gfdlsections);

    $contextbefore =~ s{
                       [ ]? (:?[,\.;]? [ ]?)?
                       permission [ ] is [ ] granted [ ] to [ ] copy [ ]?[,\.;]?[ ]?
                       distribute [ ]?[,\.;]?[ ]? and[ ]?/?[ ]?or [ ] modify [ ]
                       this [ ] document [ ] under [ ] the [ ] terms [ ] of [ ] the\Z}{}xsmo;

    # Treat ambiguous empty text
    if ($gfdlsections eq $EMPTY) {

        # lie in order to check more part
        $self->pointed_hint('license-problem-gfdl-invariants-empty',
            $item->pointer);

        return 0;
    }

    # official wording
    if(
        $gfdlsections =~ m{\A
                          with [ ] no [ ] invariant [ ] sections[ ]?,
                          [ ]? no [ ] front(?:[ ]?-[ ]?|[ ])cover [ ] texts[ ]?,?
                          [ ]? and [ ] no [ ] back(?:[ ]?-?[ ]?|[ ])cover [ ] texts
                          \Z}xs
    ) {
        return 0;
    }

    # example are ok
    if (
        $contextbefore =~ m{following [ ] is [ ] an [ ] example
                           (:?[ ] of [ ] the [ ] license [ ] notice [ ] to [ ] use
                            (?:[ ] after [ ] the [ ] copyright [ ] (?:line(?:\(s\)|s)?)?
                             (?:[ ] using [ ] all [ ] the [ ] features? [ ] of [ ] the [ ] gfdl)?
                            )?
                           )? [ ]? [,:]? \Z}xs
    ){
        return 0;
    }

    # GFDL license, assume it is bad unless it
    # explicitly states it has no "bad sections".
    for my $gfdl_fragment (keys %{$self->GFDL_FRAGMENTS}) {

        my $gfdl_data = $self->GFDL_FRAGMENTS->{$gfdl_fragment};
        my $gfdlsectionsregex = $gfdl_data->{'gfdlsectionsregex'};
        if ($gfdlsections =~ m{$gfdlsectionsregex}) {

            my $acceptonlyinfile = $gfdl_data->{'acceptonlyinfile'};
            if ($item->name =~ m{$acceptonlyinfile}) {

                my $applytag = $gfdl_data->{'tag'};

                # lie will allow checking more blocks
                $self->pointed_hint($applytag, $item->pointer,
                    'invariant part is:',
                    $gfdlsections)
                  if defined $applytag;

                return 0;

            } else {
                $self->pointed_hint(
                    'license-problem-gfdl-invariants',
                    $item->pointer,'invariant part is:',
                    $gfdlsections
                );
                return 1;
            }
        }
    }

    # catch all
    $self->pointed_hint(
        'license-problem-gfdl-invariants',
        $item->pointer,'invariant part is:',
        $gfdlsections
    );

    return 1;
}

sub rfc_whitelist_filename {
    my ($self, $item, $tag_name, %matchedhash) = @_;

    return 0
      if $item->name eq 'debian/copyright';

    my $lcname = lc($item->basename);

    # prebuilt-file or forbidden file type
    # specified separator protects against spaces in pattern
    my $RFC_WHITELIST= $self->data->load('cruft/rfc-whitelist',qr/\s*\~\~\s*/);

    my @patterns = $RFC_WHITELIST->all;

    return 0
      if any { $lcname =~ m/ $_ /xms } @patterns;

    $self->pointed_hint($tag_name, $item->pointer);

    return 1;
}

sub php_source_whitelist {
    my ($self, $item, $tag_name, %matchedhash) = @_;

    my $copyright_path
      = $self->processable->patched->resolve_path('debian/copyright');

    return 0
      if defined $copyright_path
      && $copyright_path->bytes
      =~ m{^Source: https?://pecl.php.net/package/.*$}m;

    return 0
      if $self->processable->source_name =~ /^php\d*(?:\.\d+)?$/xms;

    $self->pointed_hint($tag_name, $item->pointer);

    return 1;
}

sub clean_text {
    my ($text) = @_;

    # be paranoiac replace gnu with texinfo by gnu
    $text =~ s{
                 (?:@[[:alpha:]]*?\{)?\s*gnu\s*\}                   # Texinfo cmd
             }{ gnu }gxms;

    # pod2man formatting
    $text =~ s{ \\ \* \( [LR] \" }{\"}gxsm;
    $text =~ s{ \\ -}{-}gxsm;

    # replace some shortcut (clisp)
    $text =~ s{\(&fdl;\)}{ }gxsm;
    $text =~ s{&fsf;}{free software foundation}gxsm;

    # non breaking space
    $text =~ s{&nbsp;}{ }gxsm;

    # replace some common comment-marker/markup with space
    $text =~ s{^\.\\\"}{ }gxms;               # man comments

    # po comment may include html tag
    $text =~ s/\"\s?\v\#~\s?\"//gxms;

    # strip .rtf paragraph marks (#892967)
    $text =~ s/\\par\b//gxms;

    $text =~ s/\\url[{][^}]*?[}]/ /gxms;      # (la)?tex url
    $text =~ s/\\emph[{]/ /gxms;              # (la)?tex emph
    $text =~ s<\\href[{][^}]*?[}]
                     [{]([^}]*?)[}]>< $1 >gxms;# (la)?tex href
    $text =~ s<\\hyperlink
                 [{][^}]*?[}]
                 [{]([^}]*?)[}]>< $1 >gxms;    # (la)?tex hyperlink
    $text =~ s{-\\/}{-}gxms;                   # tex strange hyphen
    $text =~ s/\\char/ /gxms;                 # tex  char command

    # Texinfo comment with end section
    $text =~ s{\@c(?:omment)?\h+
                end \h+ ifman\s+}{ }gxms;
    $text =~ s{\@c(?:omment)?\s+
                noman\s+}{ }gxms;              # Texinfo comment no manual

    $text =~ s/\@c(?:omment)?\s+/ /gxms;      # Texinfo comment

    # Texinfo bold,italic, roman, fixed width
    $text =~ s/\@[birt][{]/ /gxms;
    $text =~ s/\@sansserif[{]/ /gxms;         # Texinfo sans serif
    $text =~ s/\@slanted[{]/ /gxms;             # Texinfo slanted
    $text =~ s/\@var[{]/ /gxms;                 # Texinfo emphasis

    $text =~ s/\@(?:small)?example\s+/ /gxms; # Texinfo example
    $text =~ s{\@end \h+
               (?:small)example\s+}{ }gxms;    # Texinfo end example tag
    $text =~ s/\@group\s+/ /gxms;             # Texinfo group
    $text =~ s/\@end\h+group\s+/ /gxms;       # Texinfo end group

    $text =~ s/<!--/ /gxms;                   # XML comments
    $text =~ s/-->/ /gxms;                    # end XML comment

    $text =~ s{</?a[^>]*?>}{ }gxms;           # a link
    $text =~ s{<br\s*/?>}{ }gxms;             # (X)?HTML line
     # breaks
    $text =~ s{</?citetitle[^>]*?>}{ }gxms;   # DocBook citation title
    $text =~ s{</?div[^>]*?>}{ }gxms;         # html style
    $text =~ s{</?font[^>]*?>}{ }gxms;        # bold
    $text =~ s{</?b[^>]*?>}{ }gxms;           # italic
    $text =~ s{</?i[^>]*?>}{ }gxms;           # italic
    $text =~ s{</?link[^>]*?>}{ }gxms;        # xml link
    $text =~ s{</?p[^>]*?>}{ }gxms;           # html paragraph
    $text =~ s{</?quote[^>]*?>}{ }gxms;       # xml quote
    $text =~ s{</?span[^>]*?>}{ }gxms;        # span tag
    $text =~ s{</?ulink[^>]*?>}{ }gxms;       # ulink DocBook
    $text =~ s{</?var[^>]*?>}{ }gxms;         # var used by texinfo2html

    $text =~ s{\&[lr]dquo;}{ }gxms;           # html rquote

    $text =~ s{\(\*note.*?::\)}{ }gxms;       # info file note

    # String array (e.g. "line1",\n"line2")
    $text =~ s/\"\s*,/ /gxms;
    # String array (e.g. "line1"\n ,"line2"),
    $text =~ s/,\s*\"/ /gxms;
    $text =~ s/\\n/ /gxms;                    # Verbatim \n in string array

    $text =~ s/\\&/ /gxms;                    # pod2man formatting
    $text =~ s/\\s(?:0|-1)/ /gxms;            # pod2man formatting

    $text =~ s/(?:``|'')/ /gxms;              # quote like

    # diff/patch lines (should be after html tag)
    $text =~ s/^[-\+!<>]/ /gxms;
    $text =~ s{\@\@ \s*
               [-+] \d+,\d+ \s+
               [-+] \d+,\d+ \s*
               \@\@}{ }gxms;                   # patch line

    # Texinfo end tag (could be more clever but brute force is fast)
    $text =~ s/}/ /gxms;
    # Tex section titles
    $text =~ s/^\s*\\(sub)*section\*?\{\s*\S+/ /gxms;
    # single char at end
    # String, C-style comment/javadoc indent,
    # quotes for strings, pipe and backslash, tilde in some txt
    $text =~ s/[%\*\"\|\\\#~]/ /gxms;
    # delete double spacing now and normalize spacing
    # to space character
    $text =~ s{\s++}{ }gsm;

    # trim both ends
    $text =~ s/^\s+|\s+$//g;

    return $text;
}

# do not use space around punctuation
sub _strip_punct() {
    my ($text) = @_;
    # replace final punctuation
    $text =~ s{(?:
        \s*[,\.;]\s*\Z               |  # final punctuation
        \A\s*[,\.;]\s*                  # punctuation at the beginning
    )}{ }gxms;

    # delete double spacing now and normalize spacing
    # to space character
    $text =~ s{\s++}{ }gsm;

    # trim both ends
    $text =~ s/^\s+|\s+$//g;

    return $text;
}

sub check_for_single_bad_license {
    my ($self, $item, $lowercase, $clean, $tag_name, $license_data) = @_;

    # do fast keyword search
    # could make more sense as 'return 1 unless all' but does not work
    return 0
      if none { $lowercase =~ / \Q$_\E /msx } @{$license_data->{keywords}};

    return 0
      if none { $clean =~ / \Q$_\E /msx }@{$license_data->{sentences}};

    my $regex = $license_data->{regex};
    return 0
      if defined $regex && $clean !~ $regex;

    my $callsub = $license_data->{callsub};
    if (!defined $callsub) {

        $self->pointed_hint($tag_name, $item->pointer);
        return 1;
    }

    return $self->$callsub($item, $tag_name, %+);
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

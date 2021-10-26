# cruft -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright © 1999 Joey Hess
# Copyright © 2000 Sean 'Shaleh' Perry
# Copyright © 2002 Josip Rodin
# Copyright © 2007 Russ Allbery
# Copyright © 2013-2018 Bastien ROUCARIÈS
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Check::Cruft;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename qw(basename);
use List::SomeUtils qw(any none first_value);
use List::UtilsBy qw(max_by);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;
use Lintian::Util qw(normalize_pkg_path);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Half of the size used in the "sliding window" for detecting bad
# licenses like GFDL with invariant sections.
# NB: Keep in sync cruft-gfdl-fp-sliding-win/pre_build.
# not less than 8192 for source missing
const my $LARGE_BLOCK_SIZE => 16_384;

const my $SMALL_BLOCK_SIZE => 8_192;

# very long line lengths
const my $VERY_LONG_LINE_LENGTH => 512;
const my $SAFE_LINE_LENGTH => 256;

const my $EMPTY => q{};
const my $ASTERISK => q{*};
const my $DOLLAR => q{$};
const my $DOT => q{.};
const my $DOUBLE_DOT => q{..};

const my $LICENSE_CHECK_DATA_FIELDS => 5;

const my $ITEM_NOT_FOUND => -1;
const my $SKIP_HTML => -1;

# prebuilt-file or forbidden file type
has RFC_WHITELIST => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;
        return $self->profile->load_data(
            'cruft/rfc-whitelist',
            qr/\s*\~\~\s*/,
            sub {
                return qr/$_[0]/xms;
            });
    });

# get browserified regexp
has BROWSERIFY_REGEX => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'cruft/browserify-regex',
            qr/\s*\~\~\s*/,
            sub {
                return qr/$_[1]/xms;
            });
    });

my %NVIDIA_LICENSE = (
    keywords => [qw{license intellectual retain property}],
    sentences =>[
'retain all intellectual property and proprietary rights in and to this software and related documentation'
    ]);

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
    });

# get usual data about admissible/not admissible GFDL invariant part of license
has GFDL_FRAGMENTS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'cruft/gfdl-license-fragments-checks',
            qr/\s*\~\~\s*/,
            sub {
                my ($gfdlsectionsregex,$secondpart) = @_;

                # allow empty parameters
                $gfdlsectionsregex //= $EMPTY;

                # trim both ends
                $gfdlsectionsregex =~ s/^\s+|\s+$//g;

                $secondpart //= $EMPTY;
                my ($acceptonlyinfile,$applytag)
                  = split(/\s*\~\~\s*/, $secondpart, 2);

                $acceptonlyinfile //= $EMPTY;
                $applytag //= $EMPTY;

                # trim both ends
                $acceptonlyinfile =~ s/^\s+|\s+$//g;
                $applytag =~ s/^\s+|\s+$//g;

                # empty first field is everything
                if (length($gfdlsectionsregex) == 0) {
                    $gfdlsectionsregex = $DOT . $ASTERISK;
                }
                # empty regname is none
                if (length($acceptonlyinfile) == 0) {
                    $acceptonlyinfile = $DOT . $ASTERISK;
                }

                my %ret = (
                    'gfdlsectionsregex'   => qr/$gfdlsectionsregex/xis,
                    'acceptonlyinfile' => qr/$acceptonlyinfile/xs,
                );
                unless ($applytag eq $EMPTY) {
                    $ret{'tag'} = $applytag;
                }

                return \%ret;
            });
    });

# Directory checks.  These regexes match a directory that shouldn't be in the
# source package and associate it with a tag (minus the leading
# source-contains or debian-adds).  Note that only one of these regexes
# should trigger for any single directory.
my @directory_checks = (
    [qr{^(.+/)?CVS/?$}        => 'cvs-control-dir'],
    [qr{^(.+/)?\.svn/?$}      => 'svn-control-dir'],
    [qr{^(.+/)?\.bzr/?$}      => 'bzr-control-dir'],
    [qr{^(.+/)?\{arch\}/?$}   => 'arch-control-dir'],
    [qr{^(.+/)?\.arch-ids/?$} => 'arch-control-dir'],
    [qr{^(.+/)?,,.+/?$}       => 'arch-control-dir'],
    [qr{^(.+/)?\.git/?$}      => 'git-control-dir'],
    [qr{^(.+/)?\.hg/?$}       => 'hg-control-dir'],
    [qr{^(.+/)?\.be/?$}       => 'bts-control-dir'],
    [qr{^(.+/)?\.ditrack/?$}  => 'bts-control-dir'],

    # Special case (can only be triggered for diffs)
    [qr{^(.+/)?\.pc/?$} => 'quilt-control-dir'],
);

# File checks.  These regexes match files that shouldn't be in the source
# package and associate them with a tag (minus the leading source-contains or
# debian-adds).  Note that only one of these regexes should trigger for any
# given file.
my @file_checks = (
    [qr{^(.+/)?svn-commit\.(.+\.)?tmp$} => 'svn-commit-file'],
    [qr{^(.+/)?svk-commit.+\.tmp$}      => 'svk-commit-file'],
    [qr{^(.+/)?\.arch-inventory$}       => 'arch-inventory-file'],
    [qr{^(.+/)?\.hgtags$}               => 'hg-tags-file'],
    [qr{^(.+/)?\.\#(.+?)\.\d+(\.\d+)*$} => 'cvs-conflict-copy'],
    [qr{^(.+/)?(.+?)\.(r[1-9]\d*)$}     => 'svn-conflict-file'],
    [qr{\.(orig|rej)$}                  => 'patch-failure-file'],
    [qr{((^|/)[^/]+\.swp|~)$}           => 'editor-backup-file'],
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

    # prebuilt-file or forbidden file type
    $self->hint('source-contains-prebuilt-wasm-binary', $item->name)
      if $item->file_info =~ m{^WebAssembly \s \(wasm\) \s binary \s module}x;

    $self->hint('source-contains-prebuilt-windows-binary', $item->name)
      if $item->file_info
      =~ m{\b(?:PE(?:32|64)|(?:MS-DOS|COM)\s executable)\b}x;

    $self->hint('source-contains-prebuilt-silverlight-object', $item->name)
      if $item->file_info =~ m{^Zip \s archive \s data}x
      && $item->name =~ m{(?i)\.xac$}x;

    if ($item->file_info =~ m{^python \s \d(\.\d+)? \s byte-compiled}x) {

        $self->hint('source-contains-prebuilt-python-object', $item->name);

        $self->hint('source-is-missing', $item->name)
          unless $self->find_source($item,
            {'.py' => '(?i)(?:\.cpython-\d{2}|\.pypy)?\.py[co]$'});
    }

    if ($item->file_info =~ m{\bELF\b}x) {
        $self->hint('source-contains-prebuilt-binary', $item->name);

        my %patterns = map {
            $_  =>
'(?i)(?:[\.-](?:bin|elf|e|hs|linux\d+|oo?|or|out|so(?:\.\d+)*)|static|_o\.golden)?$'
        } qw(.asm .c .cc .cpp .cxx .f .F .i .ml .rc .S);

        $self->hint('source-is-missing', $item->name)
          unless $self->find_source($item, \%patterns);
    }

    if ($item->file_info =~ m{^Macromedia \s Flash}x) {

        $self->hint('source-contains-prebuilt-flash-object', $item->name);

        $self->hint('source-is-missing', $item->name)
          unless $self->find_source($item, {'.as' => '(?i)\.swf$'});
    }

    if (   $item->file_info =~ m{^Composite \s Document \s File}x
        && $item->name =~ m{(?i)\.fla$}x) {

        $self->hint('source-contains-prebuilt-flash-project', $item->name);

        $self->hint('source-is-missing', $item->name)
          unless $self->find_source($item, {'.as' => '(?i)\.fla$'});
    }

    # do not forget to change also $JS_EXT in file.pm
    if ($item->name
        =~ m{(?i)[-._](?:compiled|compressed|lite|min|pack(?:ed)?|prod|umd|yc)\.js$}x
    ) {

        $self->hint('source-contains-prebuilt-javascript-object', $item->name);
        my %patterns = map {
            $_ =>
'(?i)(?:[-._](?:compiled|compressed|lite|min|pack(?:ed)?|prod|umd|yc))?\.js$'
        } qw(.js _orig.js .js.orig .src.js -src.js .debug.js -debug.js -nc.js);

        $self->hint('source-is-missing', $item->name)
          unless $self->find_source($item, \%patterns);
    }

    return;
}

sub source {
    my ($self) = @_;

    my @added_by_debian;
    my $prefix;
    if ($self->processable->native) {

        @added_by_debian = @{$self->processable->patched->sorted_list};
        $prefix = 'source-contains';

    } else {
        my $patched = $self->processable->patched;
        my $orig = $self->processable->orig;

        @added_by_debian
          = grep { !defined $orig->lookup($_->name) } @{$patched->sorted_list};

        # remove root quilt control folder and all paths in it
        # created when 3.0 (quilt) source packages are unpacked
        @added_by_debian = grep { $_->name !~ m{^.pc/} } @added_by_debian
          if $self->processable->source_format eq '3.0 (quilt)';

        my @common_items
          = grep { defined $orig->lookup($_->name) } @{$patched->sorted_list};
        my @touched_by_debian
          = grep { $_->md5sum ne $orig->lookup($_->name)->md5sum }
          @common_items;

        $self->hint('no-debian-changes')
          unless @added_by_debian || @touched_by_debian;

        $prefix = 'debian-adds';
    }

    # ignore lintian test set; should use automatic loop in the future
    @added_by_debian = grep { $_->name !~ m{^t/} } @added_by_debian
      if $self->processable->source_name eq 'lintian';

    my @directories = grep { $_->is_dir } @added_by_debian;
    for my $directory (@directories) {

        my $rule = first_value { $directory->name =~ /$_->[0]/s }
        @directory_checks;
        $self->hint("${prefix}-$rule->[1]", $directory->name)
          if defined $rule;
    }

    my @files = grep { $_->is_file } @added_by_debian;
    for my $file (@files) {

        my $rule = first_value { $file->name =~ /$_->[0]/s } @file_checks;
        $self->hint("${prefix}-$rule->[1]", $file->name)
          if defined $rule;
    }

    return;
}

sub find_source {
    my ($self, $file, $patternref) = @_;

    $patternref //= {};

    return undef
      unless $file->is_regular_file;

    return undef
      if $self->processable->is_non_free;

    my %patterns = %{$patternref};

    my @alternatives;
    for my $replacement (keys %patterns) {

        my $newname = $file->basename;

        # empty pattern would repeat the last regex compiled
        my $pattern = $patterns{$replacement};
        $newname =~ s/$pattern/$replacement/
          if length $pattern;

        push(@alternatives, $newname)
          if length $newname;
    }

    my $index = $self->processable->patched;
    my @candidates;

    # add standard locations
    push(@candidates,
        $index->resolve_path('debian/missing-sources/' . $file->name));
    push(@candidates,
        $index->resolve_path('debian/missing-sources/' . $file->basename));

    my $dirname = $file->dirname;
    my $parentname = basename($dirname);

    my @absolute = (
        # libtool
        '.libs',
        ".libs/$dirname",
        # mathjax
        'unpacked',
        # for missing source set in debian
        'debian',
        'debian/missing-sources',
        "debian/missing-sources/$dirname"
    );

    for my $absolute (@absolute) {
        push(@candidates, $index->resolve_path("$absolute/$_"))
          for @alternatives;
    }

    my @relative = (
        # likely in current dir
        $DOT,
        # for binary object built by libtool
        $DOUBLE_DOT,
        # maybe in src subdir
        './src',
        # maybe in ../src subdir
        '../src',
        "../../src/$parentname",
        # emscripten
        './flash-src/src/net/gimite/websocket',
    );

    for my $relative (@relative) {
        push(@candidates, $file->resolve_path("$relative/$_"))
          for @alternatives;
    }

    my @found = grep { defined } @candidates;

    # careful with behavior around empty arrays
    my $source = first_value { $_->name ne $file->name } @found;

    return $source;
}

# do basic license check against well known offender
# note that it does not replace licensecheck(1)
# and is only used for autoreject by ftp-master
sub full_text_check {
    my ($self, $item) = @_;

    my $contents = $item->decoded_utf8;
    return
      unless length $contents;

    my ($maximum, $position) = $self->maximum_line_length($contents);

    $self->hint('very-long-line-length-in-source-file',$item->name,
        "line $position is $maximum characters long (>$VERY_LONG_LINE_LENGTH)")
      if $maximum > $VERY_LONG_LINE_LENGTH
      && $item->file_info !~ m{SVG Scalable Vector Graphics image};

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

    $self->check_html_cruft($item, $lowercase)
      if $item->basename =~ /\.(?:x?html?\d?|xht)$/i;

    if ($self->_is_javascript_but_not_minified($item->name)) {
        # exception sphinx documentation
        if ($item->basename eq 'searchindex.js') {
            if ($lowercase =~ m/\A\s*search\.setindex\s* \s* \(\s*\{/xms) {

                $self->hint('source-contains-prebuilt-sphinx-documentation',
                    $item->dirname);
                return;
            }
        }

        if ($item->basename eq 'search_index.js') {
            if ($lowercase =~ m/\A\s*var\s*search_index\s*=/xms) {

                $self->hint('source-contains-prebuilt-pandoc-documentation',
                    $item->dirname);
                return;
            }
        }
        # false positive in dx package at least
        elsif ($item->basename eq 'srchidx.js') {

            return
              if $lowercase=~ m/\A\s*profiles \s* = \s* new \s* Array\s*\(/xms;
        }
        # see #745152
        # Be robust check also .js
        elsif ($item->basename eq 'deployJava.js') {
            if ($lowercase
                =~ m/(?:\A|\v)\s*var\s+deployJava\s*=\s*function/xmsi) {

                $self->hint('source-is-missing', $item->name)
                  unless $self->find_source($item,
                    {'.txt' => '(?i)\.js$', $EMPTY => $EMPTY});

                return;
            }
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
        $self->warn_long_lines($item, $lowercase);
    }

    # search link rel header
    if ($lowercase =~ / \Q rel="copyright" \E /msx) {

        my $href = $lowercase;
        $href =~ m{<link \s+
                  rel="copyright" \s+
                  href="([^"]+)" \s*/? \s*>}xmsi;

        my $url = $1 // $EMPTY;

        $self->hint('license-problem-cc-by-nc-sa', $item->name)
          if $url =~ m{^https?://creativecommons.org/licenses/by-nc-sa/};
    }

    return;
}

# check javascript in html file
sub check_html_cruft {
    my ($self, $item, $lowercase) = @_;

    my $blockscript = $lowercase;
    my $indexscript;

    while (($indexscript = index($blockscript, '<script')) > $ITEM_NOT_FOUND) {

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
            $self->check_js_script($item, $lcscript);

            return 0
              if $self->warn_long_lines($item, $lcscript);

            next;
        }

        # here we know that we have partial script. Do the check nevertheless
        # first check if we have the full <script> tag and do the check
        # if we get <script src="  "
        # then skip
        if ($blockscript =~ /\A<script[^>]*?>/sm) {

            $blockscript = substr($blockscript,$+[0]);
            $self->check_js_script($item, $blockscript);
        }

        return 0;
    }

    return 1;
}

# check if js script is minified
sub check_js_script {
    my ($self, $item, $lcscript) = @_;

    my $firstline = $EMPTY;
    for my $line (split /\n/, $lcscript) {

        if ($line =~ /^\s*$/) {
            next;

        } else {
            $firstline = $line;
            last;
        }
    }

    if ($firstline =~ m/.{0,20}((?:\bcopyright\b|[\(]c[\)]\s*\w|©).{0,50})/) {

        my $extract = $1;
        $extract =~ s/^\s+|\s+$//g;

        $self->hint('embedded-script-includes-copyright-statement',
            $item->name,'extract of copyright statement:',$extract);
    }

    return;
}

# check if file is javascript but not minified
sub _is_javascript_but_not_minified {
    my ($self, $name) = @_;

    my $isjsfile = ($name =~ m/\.js$/) ? 1 : 0;
    if ($isjsfile) {
        my $minjsregexp
          = qr/(?i)[-._](?:compiled|compressed|lite|min|pack(?:ed)?|prod|umd|yc)\.js$/;
        $isjsfile = ($name =~ m{$minjsregexp}) ? 0 : 1;
    }

    return $isjsfile;
}

sub warn_prebuilt_javascript{
    my ($self, $item, $linelength, $position, $cutoff) = @_;

    my $extratext= "line $position is $linelength characters long (>$cutoff)";

    $self->hint('source-contains-prebuilt-javascript-object',$item->name);

    # Check for missing source.  It will check
    # for the source file in well known directories
    if ($item->basename =~ m{\.js$}i) {

        $self->hint('source-is-missing', $item->name)
          unless $self->find_source(
            $item,
            {
                '.debug.js' => '(?i)\.js$',
                '-debug.js' => '(?i)\.js$',
                $EMPTY => $EMPTY
            });

    } else  {
        # html file
        $self->hint('source-is-missing', $item->name)
          unless $self->find_source($item, {'.fragment.js' => $DOLLAR});
    }

    return;
}

sub maximum_line_length {
    my ($self, $text) = @_;

    my @lines = split(/\n/, $text);
    my %line_lengths;

    my $position = 1;
    for my $line (@lines) {

        $line_lengths{$position} = length $line;

    } continue {
        ++$position;
    }

    my $longest = max_by { $line_lengths{$_} } keys %line_lengths;

    return (0, 0)
      unless defined $longest;

    return ($line_lengths{$longest}, $longest);
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

# detect browserified javascript (comment are removed here and code is stripped)
sub detect_browserify {
    my ($self, $item, $lowercase) = @_;

    $lowercase =~ s/\n/ /msg;
    for my $browserifyregex ($self->BROWSERIFY_REGEX->all) {

        my $regex = $self->BROWSERIFY_REGEX->value($browserifyregex);
        if ($lowercase =~ m{$regex}) {

            my $extra = (defined $1) ? 'code fragment:'.$1 : $EMPTY;
            $self->hint('source-contains-browserified-javascript',
                $item->name, $extra);

            last;
        }
    }
    return;
}

sub warn_long_lines {
    my ($self, $item, $lowercase) = @_;

    my ($maximum, $position) = $self->maximum_line_length($lowercase);
   # first check if line >  $VERY_LONG_LINE_LENGTH that is likely minification
   # avoid problem by recursive regex with longline
    if ($maximum > $VERY_LONG_LINE_LENGTH) {

        # clean up jslint craps line
        $lowercase =~ s{^\s*/[*][^\n]*[*]/\s*$}{}gm;
        $lowercase =~ s{^\s*//[^\n]*$}{}gm;
        $lowercase =~ s/^\s+//gm;
    }

    # strip indentation
    $lowercase =~ s/^\s+//mg;
    $lowercase = _strip_c_comments($lowercase);
    # strip empty line
    $lowercase =~ s/^\s*\n//mg;
    # remove last \n
    $lowercase =~ s/\n\Z//m;

    # detect browserification
    $self->detect_browserify($item, $lowercase);

    # retry very long line length test now: likely minified
    ($maximum, $position)= $self->maximum_line_length($lowercase);

    if ($maximum > $VERY_LONG_LINE_LENGTH) {

        $self->warn_prebuilt_javascript($item, $maximum, $position,
            $VERY_LONG_LINE_LENGTH);
        return 1;
    }

    while (length $lowercase) {

        # check line above > $SAFE_LINE_LENGTH
        my $line = $EMPTY;
        my $linelength = 0;

        my $nextposition = 0;
        while ($lowercase =~ /([^\n]+)\n?/g) {

            $line = $1;
            $linelength = length($line);

            if ($linelength > $SAFE_LINE_LENGTH) {
                $lowercase = substr($lowercase, pos($lowercase));

                last;
            }

            $linelength = 0;

        } continue {
            ++$nextposition;
        }

        # no long line
        return 0
          unless $linelength;

        # compute number of ;
        if (($line =~ tr/;/;/) > 1) {

            $self->warn_prebuilt_javascript($item, $linelength, $nextposition,
                $SAFE_LINE_LENGTH);
            return 1;
        }
    }

    return 0;
}

sub tag_gfdl {
    my ($self, $applytag, $name, $gfdlsections) = @_;

    $self->hint($applytag, $name, 'invariant part is:', $gfdlsections);

    return;
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
        $self->hint('license-problem-gfdl-invariants-empty', $item->name);

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
    for my $gfdl_fragment ($self->GFDL_FRAGMENTS->all) {

        my $gfdl_data = $self->GFDL_FRAGMENTS->value($gfdl_fragment);
        my $gfdlsectionsregex = $gfdl_data->{'gfdlsectionsregex'};
        if ($gfdlsections =~ m{$gfdlsectionsregex}) {

            my $acceptonlyinfile = $gfdl_data->{'acceptonlyinfile'};
            if ($item->name =~ m{$acceptonlyinfile}) {

                my $applytag = $gfdl_data->{'tag'};

                # lie will allow checking more blocks
                $self->tag_gfdl($applytag, $item->name, $gfdlsections)
                  if defined $applytag;

                return 0;

            } else {
                $self->tag_gfdl('license-problem-gfdl-invariants',
                    $item->name, $gfdlsections);
                return 1;
            }
        }
    }

    # catch all
    $self->tag_gfdl('license-problem-gfdl-invariants',
        $item->name, $gfdlsections);

    return 1;
}

sub rfc_whitelist_filename {
    my ($self, $item, $tag_name, %matchedhash) = @_;

    return 0
      if $item->name eq 'debian/copyright';

    my $lcname = lc($item->basename);

    my @values
      = map { $self->RFC_WHITELIST->value($_) } $self->RFC_WHITELIST->all;

    return 0
      if any { $lcname =~ m/ $_ /xms } @values;

    $self->hint($tag_name, $item->name);

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

    $self->hint($tag_name, $item->name);

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
      if none { $clean =~ / \Q$_\E /msx }
    @{$license_data->{sentences}};

    my $regex = $license_data->{regex};
    return 0
      if defined $regex && $clean !~ $regex;

    my $callsub = $license_data->{callsub};
    if (!defined $callsub) {

        $self->hint($tag_name, $item->name);
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

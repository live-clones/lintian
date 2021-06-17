# cruft -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright © 1999 Joey Hess
# Copyright © 2000 Sean 'Shaleh' Perry
# Copyright © 2002 Josip Rodin
# Copyright © 2007 Russ Allbery
# Copyright © 2013-2018 Bastien ROUCARIÈS
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020 Felix Lechner
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
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;
use Lintian::Util qw(normalize_pkg_path);
use Lintian::SlidingWindow;

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

const my $WARN_FILE_DATA_FIELDS => 4;
const my $LICENSE_CHECK_DATA_FIELDS => 5;

const my $RDATA_MAGIC_LENGTH => 4;
const my $ACCEPTABLE_LIBTOOL_MAJOR => 5;
const my $ACCEPTABLE_LIBTOOL_MINOR => 2;
const my $ACCEPTABLE_LIBTOOL_DEBIAN => 2;
const my $ITEM_NOT_FOUND => -1;
const my $SKIP_HTML => -1;

# prebuilt-file or forbidden file type
has WARN_FILE_TYPE => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'cruft/warn-file-type',
            qr/\s*\~\~\s*/,
            sub {
                my ($regtype, $regname, $transformlist)
                  = split(/ \s* ~~ \s* /msx, $_[1],$WARN_FILE_DATA_FIELDS);

                die encode_utf8("Syntax error in cruft/warn-file-type $.")
                  if !defined $regtype;

                # allow empty regname
                $regname //= $EMPTY;

                # trim both ends
                $regname =~ s/^\s+|\s+$//g;

                if (length($regname) == 0) {
                    $regname = $DOT . $ASTERISK;
                }

                # build transform pair
                $transformlist //= $EMPTY;
                $transformlist =~ s/^\s+|\s+$//g;

                my $syntaxerror = 'Syntax error in cruft/warn-file-type';
                my @transformpairs;
                unless($transformlist eq $EMPTY) {
                    my @transforms = split(/\s*\&\&\s*/, $transformlist);
                    if(scalar(@transforms) > 0) {
                        foreach my $transform (@transforms) {
                            # regex transform
                            if($transform =~ m{^s/}) {
                                $transform =~ m{^s/([^/]*?)/([^/]*?)/$};
                                unless(defined($1) and defined($2)) {
                                    die encode_utf8(
                                        "$syntaxerror in transform regex $.");
                                }
                                push(@transformpairs,[$1,$2]);
                            } elsif ($transform =~ /^map\s*{/) {
                                $transform
                                  =~ m{^map \s* \{ \s* 's/([^/]*?)/\'.\$_.'/' \s* \} \s* qw\(([^\)]*)\)}x;
                                unless(defined($1) and defined($2)) {
                                    die encode_utf8(
"$syntaxerror in map transform regex $."
                                    );
                                }
                                my $words = $2;
                                my $match = $1;
                                my @wordarray = split(/\s+/,$words);
                                if(scalar(@wordarray) == 0) {
                                    die encode_utf8(
"$syntaxerror in map transform regex : no qw arg $."
                                    );
                                }
                                foreach my $word (@wordarray) {
                                    push(@transformpairs,[$match, $word]);
                                }
                            } else {
                                die encode_utf8(
                                    "$syntaxerror in last field $.");
                            }
                        }
                    }
                }

                return {
                    'regtype'   => qr/$regtype/x,
                    'regname' => qr/$regname/x,
                    'checkmissing' => (not not scalar(@transformpairs)),
                    'transform' => \@transformpairs,
                };
            });
    });

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

# "Known good" files that match eg. lena.jpg.
has LENNA_WHITELIST => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('cruft/lenna-whitelist');
    });

# prebuilt-file or forbidden copyright
has BAD_LINK_COPYRIGHT => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'cruft/bad-link-copyright',
            qr/\s*\~\~\s*/,
            sub {
                return qr/$_[1]/xms;
            });
    });

# get javascript name
sub _minified_javascript_name_regexp {
    my ($self) = @_;
    my $jsv
      = $self->WARN_FILE_TYPE->value(
        'source-contains-prebuilt-javascript-object');
    return defined($jsv)
      ? $jsv->{'regname'}
      : qr/(?i)[-._](?:min|pack(?:ed)?)\.js$/;
}

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

sub _get_license_check_file {
    my ($self, $filename) = @_;

    my $data = $self->profile->load_data(
        $filename,
        qr/\s*\~\~\s*/,
        sub {
            my %LICENSE_CHECK_DISPATCH_TABLE= (
                'license-problem-gfdl-invariants' =>
                  \&check_gfdl_license_problem,
                'rfc-whitelist-filename' =>\&rfc_whitelist_filename,
                'php-source-whitelist' => \&php_source_whitelist,
                #'print-group'          => sub { print($1)},
            );
            my ($keywords, $sentence, $regex, $firstregex, $callsub)
              = split(/ \s* ~~ \s* /msx, $_[1],$LICENSE_CHECK_DATA_FIELDS);

            die encode_utf8("Syntax error in $filename:$.")
              if any { !defined } ($keywords, $sentence);

            $regex //= $EMPTY;
            $firstregex //= $EMPTY;
            $callsub //= $EMPTY;

            # trim both ends
            $keywords =~ s/^\s+|\s+$//g;
            $sentence =~ s/^\s+|\s+$//g;
            $regex =~ s/^\s+|\s+$//g;
            $firstregex =~ s/^\s+|\s+$//g;
            $callsub =~ s/^\s+|\s+$//g;

            my @keywordlist = split(/\s*\&\&\s*/, $keywords);
            if(scalar(@keywordlist) < 1) {
                die encode_utf8("$filename: No keywords on line $.");
            }
            my @sentencelist = split(/\s*\|\|\s*/, $sentence);
            if(scalar(@sentencelist) < 1) {
                die encode_utf8("$filename: No sentence on line $.");
            }

            if($regex eq $EMPTY) {
                $regex = $DOT . $ASTERISK;
            }
            if($firstregex eq $EMPTY) {
                $firstregex = $regex;
            }
            my %ret = (
                'keywords' =>  \@keywordlist,
                'sentence' => \@sentencelist,
                'regex' => qr/$regex/xsm,
                'firstregex' => qr/$firstregex/xsm,
            );
            unless($callsub eq $EMPTY) {
                if(defined($LICENSE_CHECK_DISPATCH_TABLE{$callsub})) {
                    $ret{'callsub'} = $LICENSE_CHECK_DISPATCH_TABLE{$callsub};
                } else {
                    die encode_utf8("$filename: Unknown sub $.");
                }
            }
            return \%ret;
        });
    return $data;
}

# get usual non distributable license
has NON_DISTRIBUTABLE_LICENSES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->_get_license_check_file(
            'cruft/non-distributable-license');
    });

# get non free license
# get usual non distributable license
has NON_FREE_LICENSES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->_get_license_check_file('cruft/non-free-license');
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

# Check if the package build-depends on autotools-dev, automake,
# or libtool.
my $LIBTOOL = Lintian::Relation->new->load('libtool | dh-autoreconf');
has libtool_in_build_depends => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->processable->relation('Build-Depends-All')
          ->implies($LIBTOOL);
    });

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # Check for CMake cache files.  These embed the source path and hence
    # will cause FTBFS on buildds, so they should never be present
    $self->hint('source-contains-cmake-cache-file', $item->name)
      if $item->basename eq 'CMakeCache.txt';

    $self->hint('source-contains-debian-substvars', $item->name)
      if $item->name =~ m{^debian/(?:.+\.)?substvars$}s;

    # check full text problem
    $self->full_text_check($item);

    # waf is not allowed
    if (   $item->basename =~ / \b waf $/sx
        && $item->is_open_ok) {

        my $marker = 0;
        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        while (my $line = <$fd>) {
            next unless $line =~ m/^#/;
            if ($marker && $line =~ m/^#BZ[h0][0-9]/) {
                $self->hint('source-contains-waf-binary', $item->name);
                last;
            }
            $marker = 1 if $line =~ m/^#==>/;

            # We could probably stop here, but just in case
            $marker = 0 if $line =~ m/^#<==/;
        }
        close($fd);
    }

    # .chm files are usually generated by non-free software
    $self->hint('source-contains-prebuilt-ms-help-file', $item->name)
      if  $item->basename =~ /\.chm$/i
      && $item->file_info eq 'MS Windows HtmlHelp Data'
      && $item->bytes !~ / Halibut, /msx;

    # Ensure we have a README.source for R data files
    if (   $item->basename =~ /\.(?:rda|Rda|rdata|Rdata|RData)$/
        && $item->is_open_ok
        && $item->file_info =~ /gzip compressed data/
        && !$self->processable->patched->resolve_path('debian/README.source')){

        open(my $fd, '<:gzip', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        read($fd, my $magic, $RDATA_MAGIC_LENGTH)
          or die encode_utf8('Cannot read from ' . $item->unpacked_path);

        close($fd);

        $self->hint('r-data-without-readme-source', $item->name)
          if $magic eq 'RDX2';
    }

    if (   $item->name =~ /configure\.(in|ac)$/
        && $item->is_open_ok) {

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        while (my $line = <$fd>) {
            next if $line =~ m{^\s*dnl};
            $self->hint(
                'autotools-pkg-config-macro-not-cross-compilation-safe',
                $item->name, "(line $.)")
              if $line=~ m{AC_PATH_PROG\s*\([^,]+,\s*\[?pkg-config\]?\s*,};
        }
        close($fd);
    }

    # Lena Söderberg image
    if ($item->basename =~ /\blenn?a\b/i) {
        if(    $item->file_info =~ /\bimage\b/i
            or $item->file_info =~ /^Matlab v\d+ mat/i
            or $item->file_info =~ /\bbitmap\b/i
            or $item->file_info =~ /^PDF Document\b/i
            or $item->file_info =~ /^Postscript Document\b/i) {

            $self->hint('license-problem-non-free-img-lenna', $item->name)
              unless $self->LENNA_WHITELIST->recognizes($item->md5sum);
        }
    }

    # warn by file type
    foreach my $tag_filetype ($self->WARN_FILE_TYPE->all) {
        my $warn_data = $self->WARN_FILE_TYPE->value($tag_filetype);
        my $regtype = $warn_data->{'regtype'};

        if($item->file_info =~ m{$regtype}) {
            my $regname = $warn_data->{'regname'};

            if($item->name =~ m{$regname}) {
                $self->hint($tag_filetype, $item->name);

                if($warn_data->{'checkmissing'}) {
                    my %hash;
                    $hash{$_->[1]} = $_->[0]
                      for @{$warn_data->{'transform'} // []};

                    $self->hint('source-is-missing', $item->name)
                      unless $self->find_source($item, \%hash);
                }
            }
        }
    }

    # here we check old upstream specification
    # debian/upstream should be a directory
    $self->hint('debian-upstream-obsolete-path', $item->name)
      if $item->name eq 'debian/upstream'
      || $item->name eq 'debian/upstream-metadata.yaml';

    $self->hint('readme-source-is-dh_make-template')
      if $item->name eq 'debian/README.source'
      && $item->bytes
      =~ / \QYou WILL either need to modify or delete this file\E /isx;

    if (   $item->name =~ m{^debian/(README.source|copyright|rules|control)$}
        && $item->is_open_ok) {

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        while (my $line = <$fd>) {
            next unless $line =~ m/(?<!")(FIX_?ME)(?!")/;
            $self->hint('file-contains-fixme-placeholder',
                $item->name . ":$. $1");
        }
        close $fd;
    }

    # Find mentioning of usr/lib/perl5 inside the packaging
    $self->hint('mentions-deprecated-usr-lib-perl5-directory', $item->name)
      if $item->basename ne 'changelog'
      && $item->name =~ m{^ debian/ }sx
      && $item->name !~ m{^ debian/patches/ }sx
      && $item->name !~ m{^ debian/ (?:.+\.)? install $}sx
      && $item->bytes =~ m{^ [^#]* usr/lib/perl5 }msx;

    $self->hint('source-contains-prebuilt-doxygen-documentation',
        $item->dirname)
      if $item->basename =~ m{^doxygen.(?:png|sty)$}
      and $self->processable->source_name ne 'doxygen';

    # Tests of autotools files are a special case.  Ignore
    # debian/config.cache as anyone doing that probably knows what
    # they're doing and is using it as part of the build.
    $self->hint('configure-generated-file-in-source', $item->name)
      if $item->basename =~ m{\A config.(?:cache|log|status) \Z}xsm
      && $item->name !~ m{^ debian/ }sx;

    $self->hint('ancient-libtool', $item->name)
      if $item->basename eq 'ltconfig'
      && $item->name !~ m{^ debian/ }sx
      && !$self->libtool_in_build_depends;

    if (   $item->basename eq 'ltmain.sh'
        && $item->name !~ m{^ debian/ }sx
        && !$self->libtool_in_build_depends) {

        if ($item->bytes =~ /^VERSION=[\"\']?(1\.(\d)\.(\d+)(?:-(\d))?)/m) {
            my ($version, $major, $minor, $debian)=($1, $2, $3, $4);

            $debian //= 0;

            $self->hint('ancient-libtool', $item->name, $version)
              if $major < $ACCEPTABLE_LIBTOOL_MAJOR
              || (
                $major == $ACCEPTABLE_LIBTOOL_MAJOR
                && (
                    $minor < $ACCEPTABLE_LIBTOOL_MINOR
                    || (   $minor == $ACCEPTABLE_LIBTOOL_MINOR
                        && $debian < $ACCEPTABLE_LIBTOOL_DEBIAN)));
        }
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

    # license string in debian/changelog are probably just change
    # Ignore these strings in d/README.{Debian,source}.  If they
    # appear there it is probably just "file XXX got removed
    # because of license Y".
    if (   $item->name eq 'debian/changelog'
        or $item->name eq 'debian/README.Debian'
        or $item->name eq 'debian/README.source') {
        return;
    }

    open(my $fd, '<:raw', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    # check only text files
    unless (-T $fd) {
        close($fd);
        return;
    }

    my $ishtml = ($item->basename =~ /\.(?:x?html?\d?|xht)$/i);
    my $skiphtml = 0;

    # some js file comments are really really long
    my $sfd = Lintian::SlidingWindow->new;
    $sfd->handle($fd);
    $sfd->blocksize($LARGE_BLOCK_SIZE);

    my %licenseproblemhash;

    # we try to read this file in block and use a sliding window
    # for efficiency.  We store two blocks in @queue and the whole
    # string to match in $block. Please emit license tags only once
    # per file
  BLOCK:
    while (my $block = $sfd->readwindow) {
        my $lowercase = lc($block);
        my ($cleanedblock, %matchedkeyword);
        my $blocknumber = $sfd->blocknumber;

        # Check for non-distributable files - this
        # applies even to non-free, as we still need
        # permission to distribute those.
        if(
            $self->license_check(
                $item->name,$item->basename,
                $self->NON_DISTRIBUTABLE_LICENSES,$lowercase,
                $blocknumber,\$cleanedblock,
                \%matchedkeyword,\%licenseproblemhash
            )
        ){
            last BLOCK;
        }

        # Skip the rest of the license checks for non-free
        # sections.
        if ($self->processable->is_non_free) {
            next BLOCK;
        }

        $self->license_check($item->name,$item->basename,
            $self->NON_FREE_LICENSES,$lowercase,
            $blocknumber,\$cleanedblock,\%matchedkeyword,\%licenseproblemhash);

        # check html
        if($ishtml && !$skiphtml) {
            if($self->check_html_cruft($item, $lowercase,$blocknumber) < 0) {
                $skiphtml = 1;
            }
        }
        # check only in block 0
        if($blocknumber == 0) {
            $self->search_in_block0($item, $lowercase);
        }
    }
    close($fd);
    return;
}

# check javascript in html file
sub check_html_cruft {
    my ($self, $item, $block, $blocknumber) = @_;

    my $blockscript = $block;
    my $indexscript;

    if ($blocknumber == 0) {
        if ($block =~ / \Q<meta name="generator"\E /msx) {
            if(
                $block =~ m{<meta \s+ name="generator" \s+
                content="doxygen}smx
                # Identify and ignore documentation templates by looking
                # for the use of various interpolated variables.
                # <http://www.doxygen.nl/manual/config.html#cfg_html_header>
                && $block
                !~ /\$(?:doxygenversion|projectname|projectnumber|projectlogo)\b/
            ){
                $self->hint('source-contains-prebuilt-doxygen-documentation',
                    $item);

                return $SKIP_HTML;
            }
        }
    }

    while(($indexscript = index($blockscript, '<script')) > $ITEM_NOT_FOUND) {
        $blockscript = substr($blockscript,$indexscript);
        # sourced script ok
        if ($blockscript =~ m{\A<script\s+[^>]*?src="[^"]+?"[^>]*?>}sm) {
            $blockscript = substr($blockscript,$+[0]);
            next;
        }
        # extract script
        if ($blockscript =~ m{<script[^>]*?>(.*?)</script>}sm) {
            $blockscript = substr($blockscript,$+[0]);
            if($self->check_js_script($item, $1)) {
                return 0;
            }
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
        }else {
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

    return $self->linelength_test($item, $lcscript);
}

# check if file is javascript but not minified
sub _is_javascript_but_not_minified {
    my ($self, $name) = @_;
    my $isjsfile = ($name =~ m/\.js$/) ? 1 : 0;
    if($isjsfile) {
        my $minjsregexp = $self->_minified_javascript_name_regexp();
        $isjsfile = ($name =~ m{$minjsregexp}) ? 0 : 1;
    }
    return $isjsfile;
}

# search something in block $0
sub search_in_block0 {
    my ($self, $item, $block) = @_;

    if($self->_is_javascript_but_not_minified($item->name)) {
        # exception sphinx documentation
        if($item->basename eq 'searchindex.js') {
            if($block =~ m/\A\s*search\.setindex\s* \s* \(\s*\{/xms) {
                $self->hint('source-contains-prebuilt-sphinx-documentation',
                    $item->dirname);
                return;
            }
        }
        if($item->basename eq 'search_index.js') {
            if($block =~ m/\A\s*var\s*search_index\s*=/xms) {
                $self->hint('source-contains-prebuilt-pandoc-documentation',
                    $item->dirname);
                return;
            }
        }
        # false positive in dx package at least
        elsif($item->basename eq 'srchidx.js') {
            if($block =~ m/\A\s*profiles \s* = \s* new \s* Array\s*\(/xms) {
                return;
            }
        }
        # see #745152
        # Be robust check also .js
        elsif($item->basename eq 'deployJava.js') {
            if($block =~ m/(?:\A|\v)\s*var\s+deployJava\s*=\s*function/xmsi) {
                $self->hint('source-is-missing', $item->name)
                  unless $self->find_source($item,
                    {'.txt' => '(?i)\.js$', $EMPTY => $EMPTY});
                return;
            }
        }
        # https://github.com/rafaelp/css_browser_selector is actually the
        # original source. (#874381)
        elsif ($block =~ m/css_browser_selector\(/) {
            return;
        }
        # Avoid false-positives in Jush's syntax highlighting definition files.
        elsif ($block =~ m/jush\.tr\./) {
            return;
        }

        # now search hidden minified
        $self->linelength_test($item, $block);
    }
    # search link rel header
    if ($block =~ / \Q rel="copyright" \E /msx) {
        my $href = $block;
        $href =~ m{<link \s+
                  rel="copyright" \s+
                  href="([^"]+)" \s*/? \s*>}xmsi;
        if(defined($1)) {
            my $copyrighttarget = $1;
            foreach my $badcopyrighttag ($self->BAD_LINK_COPYRIGHT->all) {
                my $regex=  $self->BAD_LINK_COPYRIGHT->value($badcopyrighttag);
                if($copyrighttarget =~ m{$regex}) {
                    $self->hint($badcopyrighttag, $item->name);
                    last;
                }
            }
        }
    }
    return;
}

# warn about prebuilt javascript and check missing source
sub warn_prebuilt_javascript{
    my ($self, $item, $linelength,$cutoff) = @_;

    my $extratext
      =  'line length is '.int($linelength)." characters (>$cutoff)";
    $self->hint('source-contains-prebuilt-javascript-object',
        $item->name,$extratext);
    # Check for missing source.  It will check
    # for the source file in well known directories
    if ($item->basename =~ m{\.js$}i) {
        $self->hint('source-is-missing', $item->name, $extratext)
          unless $self->find_source(
            $item,
            {
                '.debug.js' => '(?i)\.js$',
                '-debug.js' => '(?i)\.js$',
                $EMPTY => $EMPTY
            });
    } else  {
        # html file
        $self->hint('source-is-missing', $item->name, $extratext)
          unless $self->find_source($item, {'.fragment.js' => $DOLLAR});
    }
    return;
}

# detect if max line of block is > cutoff
# return false if file is minified
sub _linelength_test_maxlength {
    my ($block, $cutoff) = @_;
    while($block =~ /([^\n]+)\n?/g){
        my $linelength = length($1);
        if($linelength > $cutoff) {
            return ($linelength,$1,substr($block,pos($block)));
        }
    }
    return (0, $EMPTY, $block);
}

# strip C comment
# warning block is at more 8192 char in order to be too slow
# and in order to avoid regex recursion
sub _strip_c_comments {
    my ($block) = @_;
    # from perl faq strip comments
    $block =~ s{
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
    return $block;
}

# detect browserified javascript (comment are removed here and code is stripped)
sub detect_browserify {
    my ($self, $item, $block) = @_;

    $block =~ s/\n/ /msg;
    foreach my $browserifyregex ($self->BROWSERIFY_REGEX->all) {
        my $regex = $self->BROWSERIFY_REGEX->value($browserifyregex);
        if($block =~ m{$regex}) {
            my $extra = (defined $1) ? 'code fragment:'.$1 : $EMPTY;
            $self->hint('source-contains-browserified-javascript',
                $item->name, $extra);
            last;
        }
    }
    return;
}

# try to detect non human source based on line length
sub linelength_test {
    my ($self, $item, $block) = @_;

    my $linelength = 0;
    my $line;
    my $nextblock;

    ($linelength)= _linelength_test_maxlength($block,$VERY_LONG_LINE_LENGTH);
   # first check if line >  $VERY_LONG_LINE_LENGTH that is likely minification
   # avoid problem by recursive regex with longline
    if($linelength) {
        $self->hint(
            'very-long-line-length-in-source-file',
            $item->name,'line length is',
            int($linelength),'characters (>'.$VERY_LONG_LINE_LENGTH.')'
        );
        # clean up jslint craps line
        $block =~ s{^\s*/[*][^\n]*[*]/\s*$}{}gm;
        $block =~ s{^\s*//[^\n]*$}{}gm;
        $block =~ s/^\s+//gm;

        # try to remove comments in first 8192 block (license...)
        my $block8192 = substr($block, 0, $SMALL_BLOCK_SIZE);
        $block8192 = _strip_c_comments($block8192);
        $block
          = length($block) > $SMALL_BLOCK_SIZE
          ? $block8192.substr($block, $SMALL_BLOCK_SIZE)
          : $block8192;

        # strip empty line
        $block =~ s/^\s*\n//mg;
        # remove last \n
        $block =~ s/\n\Z//m;

        # detect browserification
        $self->detect_browserify($item, $block);

        # retry very long line length test now: likely minified
        ($linelength)
          = _linelength_test_maxlength($block,$VERY_LONG_LINE_LENGTH);

        if($linelength) {
            $self->warn_prebuilt_javascript($item, $linelength,
                $VERY_LONG_LINE_LENGTH);
            return 1;
        }
    }
    # Now try to be more clever and work only on the 8192 character
    # in order to avoid regexp recursion problems
    my $strip = substr($block, 0, $SMALL_BLOCK_SIZE);
    # strip indention
    $strip =~ s/^\s+//mg;
    $strip = _strip_c_comments($block);
    # strip empty line
    $strip =~ s/^\s*\n//mg;
    # remove last \n
    $strip =~ s/\n\Z//m;
    $nextblock = $strip;

    # detect browserified
    $self->detect_browserify($item, $nextblock);

    while(length($nextblock)) {
        # check line above > $SAFE_LINE_LENGTH
        ($linelength,$line,$nextblock)
          = _linelength_test_maxlength($nextblock,$SAFE_LINE_LENGTH);
        # no long line
        unless($linelength) {
            return 0;
        }
        # compute number of ;
        if(($line =~ tr/;/;/) > 1) {
            $self->warn_prebuilt_javascript($item, $linelength,
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
    my (
        $self, $name,$basename,
        $block,$blocknumber,$cleanedblock,
        $matchedkeyword,$licenseproblemhash,$licenseproblem,
        %matchedhash
    )= @_;

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
    unless(
        defined(
            $licenseproblemhash->{'license-problem-gfdl-invariants-empty'})
    ) {
        if ($gfdlsections eq $EMPTY) {
            # lie in order to check more part
            $self->hint('license-problem-gfdl-invariants-empty', $name);
            $licenseproblemhash->{'license-problem-gfdl-invariants-empty'}= 1;
            return 0;
        }
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
    foreach my $gfdl_fragment ($self->GFDL_FRAGMENTS->all) {
        my $gfdl_data = $self->GFDL_FRAGMENTS->value($gfdl_fragment);
        my $gfdlsectionsregex = $gfdl_data->{'gfdlsectionsregex'};
        if ($gfdlsections =~ m{$gfdlsectionsregex}) {
            my $acceptonlyinfile = $gfdl_data->{'acceptonlyinfile'};
            if ($name =~ m{$acceptonlyinfile}) {
                my $applytag = $gfdl_data->{'tag'};
                if(defined($applytag)) {
                    unless(defined($licenseproblemhash->{$applytag})) {
                        # lie will allow checking more blocks
                        $self->tag_gfdl($applytag, $name, $gfdlsections);
                        $licenseproblemhash->{$applytag} = 1;
                        return 0;
                    }
                }
                return 0;
            }else {
                $self->tag_gfdl('license-problem-gfdl-invariants',
                    $name, $gfdlsections);
                return 1;
            }
        }
    }

    # catch all clause
    $self->tag_gfdl('license-problem-gfdl-invariants', $name, $gfdlsections);
    return 1;
}

# whitelist good rfc
sub rfc_whitelist_filename {
    my (
        $self, $name,$basename,
        $block,$blocknumber,$cleanedblock,
        $matchedkeyword,$licenseproblemhash,$licenseproblem,
        %matchedhash
    )= @_;

    return 0 if $name eq 'debian/copyright';
    my $lcname = lc($basename);

    foreach my $rfc_regexp ($self->RFC_WHITELIST->all) {
        my $regex = $self->RFC_WHITELIST->value($rfc_regexp);
        if($lcname =~ m/$regex/xms) {
            return 0;
        }
    }
    $self->hint($licenseproblem, $name);
    return 1;
}

# whitelist php source
sub php_source_whitelist {
    my (
        $self, $name,$basename,
        $block,$blocknumber,$cleanedblock,
        $matchedkeyword,$licenseproblemhash,$licenseproblem,
        %matchedhash
    )= @_;

    my $copyright_path
      = $self->processable->patched->resolve_path('debian/copyright');
    if (    $copyright_path
        and $copyright_path->bytes
        =~ m{^Source: https?://pecl.php.net/package/.*$}m) {
        return 0;
    }

    return 0
      if $self->processable->source_name =~ /^php\d*(?:\.\d+)?$/xms;

    $self->hint($licenseproblem, $name);

    return 1;
}

sub _clean_block {
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

# check bad license
sub license_check {
    my (
        $self, $name,$basename,
        $licensesdatas, $block,$blocknumber,
        $cleanedblock,$matchedkeyword,$licenseproblemhash
    )= @_;

    my $ret = 0;

    # avoid to check lintian
    if($self->processable->source_name eq 'lintian') {
        return $ret;
    }
  LICENSE:
    foreach my $licenseproblem ($licensesdatas->all) {
        my $licenseproblemdata = $licensesdatas->value($licenseproblem);
        if(defined($licenseproblemhash->{$licenseproblem})) {
            next LICENSE;
        }
        # do fast keyword search
        my @keywordslist = @{$licenseproblemdata->{'keywords'}};
        foreach my  $keyword (@keywordslist) {
            my $thiskeyword = $matchedkeyword->{$keyword};
            if(not defined($thiskeyword)) {
                if ($block =~ / \Q$keyword\E /msx) {
                    $matchedkeyword->{$keyword} = 1;
                }else {
                    $matchedkeyword->{$keyword} = 0;
                    next LICENSE;
                }
            } elsif ($thiskeyword == 0) {
                next LICENSE;
            }
        }

        # clean block now in order to normalise space and check a sentence
        ${$cleanedblock} //= _clean_block($block);

        next LICENSE
          if none { ${$cleanedblock} =~ / \Q$_\E /msx }
        @{$licenseproblemdata->{'sentence'}};

        my $regex
          = $blocknumber
          ? $licenseproblemdata->{'regex'}
          : $licenseproblemdata->{'firstregex'};

        next LICENSE
          unless ${$cleanedblock} =~ $regex;

        my $callsub = $licenseproblemdata->{'callsub'};

        if(defined $callsub) {
            my $subresult= $self->$callsub(
                $name,$basename,$block,
                $blocknumber,$cleanedblock,$matchedkeyword,
                $licenseproblemhash,$licenseproblem,%+
            );
            if($subresult) {
                $licenseproblemhash->{$licenseproblem} = 1;
                $ret = 1;
                next LICENSE;
            }
        }else {
            $self->hint($licenseproblem, $name);
            $licenseproblemhash->{$licenseproblem} = 1;
            $ret = 1;
            next LICENSE;
        }
    }
    return $ret;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

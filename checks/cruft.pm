# cruft -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
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

package Lintian::cruft;
use strict;
use warnings;
use autodie;
use v5.10;
use feature qw(switch);
use Carp qw(croak confess);

use Cwd();
use File::Find;

# Half of the size used in the "sliding window" for detecting bad
# licenses like GFDL with invariant sections.
# NB: Keep in sync cruft-gfdl-fp-sliding-win/pre_build.
use constant BLOCKSIZE => 4096;

use Lintian::Data;
use Lintian::Relation ();
use Lintian::Tags qw(tag);
use Lintian::Util qw(fail is_ancestor_of normalize_pkg_path strip);
use Lintian::SlidingWindow;

# All the packages that may provide config.{sub,guess} during the build, used
# to suppress warnings about outdated autotools helper files.  I'm not
# thrilled with having the automake exception as well, but people do depend on
# autoconf and automake and then use autoreconf to update config.guess and
# config.sub, and automake depends on autotools-dev.
our $AUTOTOOLS = Lintian::Relation->new(
    join(' | ', Lintian::Data->new('cruft/autotools')->all));

our $LIBTOOL = Lintian::Relation->new('libtool | dh-autoreconf');

# forbidden files
my $NON_DISTRIBUTABLE_FILES = Lintian::Data->new(
    'cruft/non-distributable-files',
    qr/\s*\~\~\s*/,
    sub {
        my @sliptline = split(/\s*\~\~\s*/, $_[1], 5);
        if (scalar(@sliptline) != 5) {
            fail 'Syntax error in cruft/non-distributable-files', $.;
        }
        my ($sha1, $sha256, $name, $reason, $link) = @sliptline;
        return {
            'sha1'   => $sha1,
            'sha256' => $sha256,
            'name'   => $name,
            'reason' => $reason,
            'link'   => $link,
        };
    });

# non free files
my $NON_FREE_FILES = Lintian::Data->new(
    'cruft/non-free-files',
    qr/\s*\~\~\s*/,
    sub {
        my @sliptline = split(/\s*\~\~\s*/, $_[1], 5);
        if (scalar(@sliptline) != 5) {
            fail 'Syntax error in cruft/non-free-files', $.;
        }
        my ($sha1, $sha256, $name, $reason, $link) = @sliptline;
        return {
            'sha1'   => $sha1,
            'sha256' => $sha256,
            'name'   => $name,
            'reason' => $reason,
            'link'   => $link,
        };
    });

# prebuilt-file or forbidden file type
my $WARN_FILE_TYPE =  Lintian::Data->new(
    'cruft/warn-file-type',
    qr/\s*\~\~\s*/,
    sub {
        my @sliptline = split(/\s*\~\~\s*/, $_[1], 2);
        unless (scalar(@sliptline) == 1 or scalar(@sliptline) == 2) {
            fail 'Syntax error in cruft/warn-file-type', $.;
        }
        my ($regtype, $regname) = @sliptline;

        # allow empty regname
        $regname = defined($regname) ? strip($regname) : '';
        if (length($regname) == 0) {
            $regname = '.*';
        }
        return {
            'regtype'   => qr/$regtype/x,
            'regname' => qr/$regname/x,
        };
    });

# The files that contain error messages from tar, which we'll check and issue
# tags for if they contain something unexpected, and their corresponding tags.
our %ERRORS = (
    'index-errors'    => 'tar-errors-from-source',
    'unpacked-errors' => 'tar-errors-from-source'
);

# Directory checks.  These regexes match a directory that shouldn't be in the
# source package and associate it with a tag (minus the leading
# source-contains or diff-contains).  Note that only one of these regexes
# should trigger for any single directory.
my @directory_checks = (
    [qr,^(.+/)?CVS$,        => 'cvs-control-dir'],
    [qr,^(.+/)?\.svn$,      => 'svn-control-dir'],
    [qr,^(.+/)?\.bzr$,      => 'bzr-control-dir'],
    [qr,^(.+/)?\{arch\}$,   => 'arch-control-dir'],
    [qr,^(.+/)?\.arch-ids$, => 'arch-control-dir'],
    [qr!^(.+/)?,,.+$!       => 'arch-control-dir'],
    [qr,^(.+/)?\.git$,      => 'git-control-dir'],
    [qr,^(.+/)?\.hg$,       => 'hg-control-dir'],
    [qr,^(.+/)?\.be$,       => 'bts-control-dir'],
    [qr,^(.+/)?\.ditrack$,  => 'bts-control-dir'],

    # Special case (can only be triggered for diffs)
    [qr,^(.+/)?\.pc$, => 'quilt-control-dir'],
);

# File checks.  These regexes match files that shouldn't be in the source
# package and associate them with a tag (minus the leading source-contains or
# diff-contains).  Note that only one of these regexes should trigger for any
# given file.  If the third column is a true value, don't issue this tag
# unless the file is included in the diff; it's too common in source packages
# and not important enough to worry about.
my @file_checks = (
    [qr,^(.+/)?svn-commit\.(.+\.)?tmp$, => 'svn-commit-file'],
    [qr,^(.+/)?svk-commit.+\.tmp$,      => 'svk-commit-file'],
    [qr,^(.+/)?\.arch-inventory$,       => 'arch-inventory-file'],
    [qr,^(.+/)?\.hgtags$,               => 'hg-tags-file'],
    [qr,^(.+/)?\.\#(.+?)\.\d+(\.\d+)*$, => 'cvs-conflict-copy'],
    [qr,^(.+/)?(.+?)\.(r\d+)$,          => 'svn-conflict-file'],
    [qr,\.(orig|rej)$,                  => 'patch-failure-file', 1],
    [qr,((^|/)\.[^/]+\.swp|~)$,         => 'editor-backup-file', 1],
);

# List of files to check for a LF-only end of line terminator, relative
# to the debian/ source directory
our @EOL_TERMINATORS_FILES = qw(control changelog);

sub run {
    my (undef, undef, $info) = @_;
    my $droot = $info->debfiles;

    if (-e "$droot/files" and not -z "$droot/files") {
        tag 'debian-files-list-in-source';
    }

    # This doens't really belong here, but there isn't a better place at the
    # moment to put this check.
    my $version = $info->field('version');

    # If the version field is missing, assume it to be a native,
    # maintainer upload as it is probably the most likely case.
    $version = '0-1' unless defined $version;
    if ($info->native) {
        if ($version =~ /-/ and $version !~ /-0\.[^-]+$/) {
            tag 'native-package-with-dash-version';
        }
    }else {
        if ($version !~ /-/) {
            tag 'non-native-package-with-native-version';
        }
    }

    # Check if the package build-depends on autotools-dev, automake,
    # or libtool.
    my $atdinbd = $info->relation('build-depends-all')->implies($AUTOTOOLS);
    my $ltinbd  = $info->relation('build-depends-all')->implies($LIBTOOL);

    # Create a closure so that we can pass our lexical variables into
    # the find wanted function.  We don't want to make them global
    # because we'll then leak that data across packages in a large
    # Lintian run.
    my %warned;
    my $format = $info->field('format');

    # Assume the package to be non-native if the field is not present.
    # - while 1.0 is more likely in this case, Lintian will probably get
    #   better results by checking debfiles/ rather than looking for a diffstat
    #   that may not be present.
    $format = '3.0 (quilt)' unless defined $format;
    if ($format =~ /^\s*2\.0\s*\z/ or $format =~ /^\s*3\.0\s*\(quilt\)/) {
        my $wanted = sub { check_debfiles($info, qr/\Q$droot\E/, \%warned) };
        find($wanted, $droot);
    }elsif (not $info->native) {
        check_diffstat($info->diffstat, \%warned);
    }
    find_cruft($info, \%warned, $atdinbd, $ltinbd);

    for my $file (@EOL_TERMINATORS_FILES) {
        my $path = $info->debfiles($file);
        next if not -f $path or not is_ancestor_of($droot, $path);
        open(my $fd, '<', $path);
        while (my $line = <$fd>) {
            if ($line =~ m{ \r \n \Z}xsm) {
                tag 'control-file-with-CRLF-EOLs', "debian/$file";
                last;
            }
        }
        close($fd);
    }

    # Report any error messages from tar while unpacking the source
    # package if it isn't just tar cruft.
    for my $file (keys %ERRORS) {
        my $tag  = $ERRORS{$file};
        my $path = $info->lab_data_path($file);
        if (-s $path) {
            open(my $fd, '<', $path);
            local $_;
            while (<$fd>) {
                chomp;
                s,^(?:[/\w]+/)?tar: ,,;

                # Record size errors are harmless.  Skipping to next
                # header apparently comes from star files.  Ignore all
                # GnuPG noise from not having a valid GnuPG
                # configuration directory.  Also ignore the tar
                # "exiting with failure status" message, since it
                # comes after some other error.
                next if /^Record size =/;
                next if /^Skipping to next header/;
                next if /^gpgv?: /;
                next if /^secmem usage: /;
                next if /^Exiting with failure status due to previous errors/;
                tag $tag, $_;
            }
            close($fd);
        }
    }

    return;
}    # </run>

# -----------------------------------

# Check the diff for problems.  Record any files we warn about in $warned so
# that we don't warn again when checking the full unpacked source.  Takes the
# name of a file containing diffstat output.
sub check_diffstat {
    my ($diffstat, $warned) = @_;
    my $saw_file;
    open(my $fd, '<', $diffstat);
    local $_;
    while (<$fd>) {
        my ($file) = (m,^\s+(.*?)\s+\|,)
          or fail("syntax error in diffstat file: $_");
        $saw_file = 1;

        # Check for CMake cache files.  These embed the source path and hence
        # will cause FTBFS on buildds, so they should never be touched in the
        # diff.
        if (    $file =~ m,(?:^|/)CMakeCache.txt\z,
            and $file !~ m,(?:^|/)debian/,){
            tag 'diff-contains-cmake-cache-file', $file;
        }

        # For everything else, we only care about diffs that add files.  If
        # the file is being modified, that's not a problem with the diff and
        # we'll catch it later when we check the source.  This regex doesn't
        # catch only file adds, just any diff that doesn't remove lines from a
        # file, but it's a good guess.
        next unless m,\|\s+\d+\s+\++$,;

        # diffstat output contains only files, but we consider the directory
        # checks to trigger if the diff adds any files in those directories.
        my ($directory) = ($file =~ m,^(.*)/[^/]+$,);
        if ($directory and not $warned->{$directory}) {
            for my $rule (@directory_checks) {
                if ($directory =~ /$rule->[0]/) {
                    tag "diff-contains-$rule->[1]", $directory;
                    $warned->{$directory} = 1;
                }
            }
        }

        # Now the simpler file checks.
        for my $rule (@file_checks) {
            if ($file =~ /$rule->[0]/) {
                tag "diff-contains-$rule->[1]", $file;
                $warned->{$file} = 1;
            }
        }

        # Additional special checks only for the diff, not the full source.
        if ($file =~ m@^debian/(?:.+\.)?substvars$@) {
            tag 'diff-contains-substvars', $file;
        }
    }
    close($fd);

    # If there was nothing in the diffstat output, there was nothing in the
    # diff, which is probably a mistake.
    tag 'empty-debian-diff' unless $saw_file;
    return;
}

# Check the debian directory for problems.  This is used for Format: 2.0 and
# 3.0 (quilt) packages where there is no Debian diff and hence no diffstat
# output.  Record any files we warn about in $warned so that we don't warn
# again when checking the full unpacked source.
sub check_debfiles {
    my ($info, $droot, $warned) = @_;
    (my $name = $File::Find::name) =~ s,^$droot/,,;

    # Check for unwanted directories and files.  This really duplicates the
    # find_cruft function and we should find a way to combine them.
    if (-d) {
        for my $rule (@directory_checks) {
            if ($name =~ /$rule->[0]/) {
                tag "diff-contains-$rule->[1]", "debian/$name";
                $warned->{"debian/$name"} = 1;
            }
        }
    }

    -f or return;

    for my $rule (@file_checks) {
        if ($name =~ /$rule->[0]/) {
            tag "diff-contains-$rule->[1]", "debian/$name";
            $warned->{"debian/$name"} = 1;
        }
    }

    # Additional special checks only for the diff, not the full source.
    if ($name =~ m@^(?:.+\.)?substvars$@o) {
        tag 'diff-contains-substvars', "debian/$name";
    }
    return;
}

# Check each file in the source package for problems.  By the time we get to
# this point, we've already checked the diff and warned about anything added
# there, so we only warn about things that weren't in the diff here.
#
# Report problems with native packages using the "diff-contains" rather than
# "source-contains" tag.  The tag isn't entirely accurate, but it's better
# than creating yet a third set of tags, and this gets the severity right.
sub find_cruft {
    my ($info, $warned, $atdinbd, $ltinbd) = @_;
    my $prefix = ($info->native ? 'diff-contains' : 'source-contains');
    my @worklist;

    # start with the top-level dirs
    push(@worklist, $info->index('')->children);

  ENTRY:
    while (my $entry = shift(@worklist)) {
        my $name     = $entry->name;
        my $basename = $entry->basename;
        my $path;
        my $file_info;

        if ($entry->is_dir) {

            # Remove the trailing slash (historically we never
            # included the slash for these tags and there is no
            # particular reason to change that now).
            $name     = substr($name,     0, -1);
            $basename = substr($basename, 0, -1);

            # Ignore the .pc directory and its contents, created as
            # part of the unpacking of a 3.0 (quilt) source package.

            # NB: this catches all .pc dirs (regardless of depth).  If you
            # change that, please check we have a
            # "source-contains-quilt-control-dir" tag.
            next if $basename eq '.pc';

            # Ignore files in test suites.  They may be part of the test.
            next
              if $basename =~ m{ \A t (?: est (?: s (?: et)?+ )?+ )?+ \Z}xsm;

            if (not $warned->{$name}) {
                for my $rule (@directory_checks) {
                    if ($basename =~ /$rule->[0]/) {
                        tag "${prefix}-$rule->[1]", $name;

                        # At most one rule will match
                        last;
                    }
                }
            }

            push(@worklist, $entry->children);
            next ENTRY;
        }
        if ($entry->is_symlink) {

            # An absolute link always escapes the root (of a source
            # package).  For relative links, it escapes the root if we
            # cannot normalize it.
            if ($entry->link =~ m{\A / }xsm
                or not defined($entry->link_normalized)){
                tag 'source-contains-unsafe-symlink', $name;
            }
            next ENTRY;
        }

        # we just need normal files for the rest
        next ENTRY unless $entry->is_file;

        # check non free file
        my $md5sum = $info->md5sums->{$name};
        if ($NON_DISTRIBUTABLE_FILES->known($md5sum)) {
            my $usualname= $NON_DISTRIBUTABLE_FILES->value($md5sum)->{'name'};
            my $reason = $NON_DISTRIBUTABLE_FILES->value($md5sum)->{'reason'};
            my $link   = $NON_DISTRIBUTABLE_FILES->value($md5sum)->{'link'};
            tag 'license-problem-md5sum-non-distributable-file', $name,
              "usual name is $usualname.", "$reason", "See also $link.";

            # should be stripped so pass other test
            next ENTRY;
        }
        unless ($info->is_non_free) {
            if ($NON_FREE_FILES->known($md5sum)) {
                my $usualname   = $NON_FREE_FILES->value($md5sum)->{'name'};
                my $reason = $NON_FREE_FILES->value($md5sum)->{'reason'};
                my $link   = $NON_FREE_FILES->value($md5sum)->{'link'};
                tag 'license-problem-md5sum-non-free-file', $name,
                  "usual name is $usualname.", "$reason",
                  "See also $link.";
            }
        }

        $file_info = $info->file_info($name);

        # warn by file type
        foreach my $tag_filetype ($WARN_FILE_TYPE->all) {
            my $regtype = $WARN_FILE_TYPE->value($tag_filetype)->{'regtype'};
            my $regname = $WARN_FILE_TYPE->value($tag_filetype)->{'regname'};
            if($file_info =~ m{$regtype}) {
                if($name =~ m{$regname}) {
                    tag $tag_filetype, $name;
                }
            }
        }

        # waf is not allowed
        if ($basename =~ /\bwaf$/) {
            my $path   = $info->unpacked($entry);
            my $marker = 0;
            open(my $fd, '<', $path);
            while (my $line = <$fd>) {
                next unless $line =~ m/^#/o;
                if ($marker && $line =~ m/^#BZ[h0][0-9]/o) {
                    tag 'source-contains-waf-binary', $name;
                    last;
                }
                $marker = 1 if $line =~ m/^#==>/o;

                # We could probably stop here, but just in case
                $marker = 0 if $line =~ m/^#<==/o;
            }
            close($fd);
        }

        unless ($warned->{$name}) {
            for my $rule (@file_checks) {
                next if ($rule->[2] and not $info->native);
                if ($basename =~ /$rule->[0]/) {
                    tag "${prefix}-$rule->[1]", $name;
                }
            }
        }

        # Tests of autotools files are a special case.  Ignore
        # debian/config.cache as anyone doing that probably knows what
        # they're doing and is using it as part of the build.
        if ($basename =~ m{\A config.(?:cache|log|status) \Z}xsm) {
            if ($entry->dirname ne 'debian') {
                tag 'configure-generated-file-in-source', $name;
            }
        }elsif ($basename =~ m{\A config.(?:guess|sub) \Z}xsm
            and not $atdinbd){
            open(my $fd, '<', $info->unpacked($entry));
            while (<$fd>) {
                last
                  if $.> 10;  # it's on the 6th line, but be a bit more lenient
                if (/^(?:timestamp|version)='((\d+)-(\d+).*)'$/) {
                    my ($date, $year, $month) = ($1, $2, $3);
                    if ($year < 2004) {
                        tag 'ancient-autotools-helper-file', $name, $date;
                    }elsif (($year < 2012)
                        or ($year == 2012 and $month < 4)){
                        # config.sub   >= 2012-04-18 (was 2012-02-10)
                        # config.guess >= 2012-06-10 (was 2012-02-10)
                        # Flagging anything earlier than 2012-04 as
                        # outdated works, due to the "bumped from"
                        # dates.
                        tag 'outdated-autotools-helper-file', $name, $date;
                    }
                }
            }
            close($fd);
        }elsif ($basename eq 'ltconfig' and not $ltinbd) {
            tag 'ancient-libtool', $name;
        }elsif ($basename eq 'ltmain.sh', and not $ltinbd) {
            open(my $fd, '<', $info->unpacked($entry));
            while (<$fd>) {
                if (/^VERSION=[\"\']?(1\.(\d)\.(\d+)(?:-(\d))?)/) {
                    my ($version, $major, $minor, $debian) =($1, $2, $3, $4);
                    if ($major < 5 or ($major == 5 and $minor < 2)) {
                        tag 'ancient-libtool', $name, $version;
                    }elsif ($minor == 2 and (!$debian || $debian < 2)) {
                        tag 'ancient-libtool', $name, $version;
                    }
                    last;
                }
            }
            close($fd);
        }
        license_check($info, $name, $info->unpacked($entry));
    }
    return;
}

# do basic license check against well known offender
# note that it does not replace licensecheck(1)
# and is only used for autoreject by ftp-master
sub license_check {
    my ($info, $name, $path) = @_;

    # license string in debian/changelog are probably just change
    # Ignore these strings in d/README.{Debian,source}.  If they
    # appear there it is probably just "file XXX got removed
    # because of license Y".
    if (   $name eq 'debian/changelog'
        or $name eq 'debian/README.Debian'
        or $name eq 'debian/README.source') {
        return;
    }

    # allow to check only text file
    unless(-T $path) {
        return;
    }

    my $sfd = Lintian::SlidingWindow->new('<:raw', $path, \&lc_block);
    my %licenseproblemhash = ();

    # we try to read this file in block and use a sliding window
    # for efficiency.  We store two blocks in @queue and the whole
    # string to match in $block. Please emit license tags only once
    # per file
  BLOCK:
    while (my $block = $sfd->readwindow()) {
        if (!exists $licenseproblemhash{'nvidia-intellectual'}) {
            if (   index($block, 'intellectual') > -1
                && index($block, 'retain') > -1
                && index($block, 'property') > -1){
                # nvdia opencv infamous license
                # non-distributable
                my $cleanedblock = _clean_block($block);
                if (
                    $cleanedblock =~ m/retain \s all \s intellectual \s
                          property \s and \s proprietary \s rights \s in \s
                          and \s to \s this \s software \s and \s
                          related \s documentation/xism
                  ){
                    tag 'license-problem-nvidia-intellectual', $name;
                    $licenseproblemhash{'nvidia-intellectual'} = 1;
                }
            }
        }

        # some license issues do not apply to non-free
        # because these file are distribuable
        if ($info->is_non_free) {
            next BLOCK;
        }

        if (!exists $licenseproblemhash{'json-evil'}) {
            if (   index($block, 'evil') > -1
                && index($block, 'good') > -1) {
                my $cleanedblock = _clean_block($block);
                if (
                    $cleanedblock =~ m/software \s shall \s
                     be \s used \s for \s good \s* ,? \s*
                     not \s evil/xsm
                  ){
                    # json evil license
                    tag 'license-problem-json-evil', $name;
                    $licenseproblemhash{'json-evil'} = 1;
                }
            }
        }

        # non free rfc
        if (!exists $licenseproblemhash{'non-free-RFC'}) {
            if (   index($block, 'copyrights') > -1
                && index($block, 'purpose') > -1
                && index($block, 'translate') > -1) {
                my $cleanedblock = _clean_block($block);
                if(
                    $cleanedblock =~ m/this \s document \s itself \s
                           may \s not \s
                           be \s modified \s in \s any \s way\s?,\s?
                           such \s as \s by \s removing \s the \s copyright \s
                           notice \s or \s references \s
                           to \s .{0,256}
                           \s? except \s as \s needed \s for \s
                           the \s purpose \s of \s developing \s  .{0,128}
                           \s? in \s which \s case \s the \s procedures \s
                           for \s copyrights \s defined \s in \s
                           the \s .{0,128} \s? process \s must \s be \s
                           followed\s?,\s? or \s as \s required \s to \s
                           translate \s it \s into \s languages \s other \s than/xism
                  ){
                    tag 'license-problem-non-free-RFC', $name;
                    $licenseproblemhash{'non-free-RFC'} = 1;
                }
            }
        }
        if (!exists $licenseproblemhash{'non-free-RFC'}) {
            if (index($block, 'bcp') > -1){
                my $cleanedblock = _clean_block($block);
                if (
                    $cleanedblock =~ m/This \s document \s is \s subject
                       \s to \s
                              (?:the \s rights\s?, \s licenses \s
                                 and \s restrictions \s contained \s in)?
                               \s BCP \s 78/xism
                  ){
                    tag 'license-problem-non-free-RFC', $name;
                    $licenseproblemhash{'non-free-RFC'} = 1;
                }
            }
        }

        # check GFDL block - The ".{0,1024}"-part in the regex
        # will contain the "no invariants etc."  part if
        # it is a good use of the license.  We include it
        # here to ensure that we do not emit a false positive
        # if the "redeeming" part is in the next block.
        #
        # See cruft-gfdl-fp-sliding-win for the test case
        if (!exists $licenseproblemhash{'gfdl-invariants'}) {
            if (   index($block, 'license') > -1
                && index($block, 'documentation') > -1
                && index($block, 'gnu') > -1
                && index($block, 'copy') > -1){

                # classical gfdl matching pattern
                my $normalgfdlpattern = qr/
                 (?'rawcontextbefore'(?:
                    (?:(?!a \s copy \s of \s the \s license \s is).){1024}|
                    (?:\s copy \s of \s the \s license \s is.{0,1024}?)))
                 gnu \s free \s documentation \s license
                 (?'rawgfdlsections'(?:(?!gnu \s free \s documentation \s license).){0,1024}?)
                 a \s copy \s of \s the \s license \s is
                /xsmo;

                # for first block we get context from the beginning
                my $firstblockgfdlpattern = qr/
                 (?'rawcontextbefore'(?:
                    (?:(?!a \s copy \s of \s the \s license \s is).){1024}|
                  \A(?:(?!a \s copy \s of \s the \s license \s is).){0,1024}|
                    (?:\s copy \s of \s the \s license \s is.{0,1024}?)
                  )
                 )
                 gnu \s free \s documentation \s license
                 (?'rawgfdlsections'(?:(?!gnu \s free \s documentation \s license).){0,1024}?)
                 a \s copy \s of \s the \s license \s is
                 /xsmo;

                my $gfdlpattern
                  =$sfd->blocknumber()
                  ? $normalgfdlpattern
                  : $firstblockgfdlpattern;

              # We need an "unclean" block for the $gfdlpattern as _clean_block
              # is a bit too efficient at removing stuff we look for.  On the
              # other hand, cleaning the block and using index to look for
              # "gnu free documentation license" is vastly cheaper than running
              # $gfdlpattern on the unclean block.
                my $cleanedblock = _clean_block($block);

                if (index($cleanedblock, 'gnu free documentation license') > -1
                    && $cleanedblock =~ $gfdlpattern) {
                    my %matchedhash = %+;
                    if(
                        _check_gfdl_license_problem(
                            $name,$cleanedblock,%matchedhash
                        )
                      ) {
                        $licenseproblemhash{'gfdl-invariants'} = 1;
                    }
                }
            }
        }
    }
    return;
}

# return True in case of license problem
sub _check_gfdl_license_problem {
    my ($name,$cleanedblock,%matchedhash) = @_;
    my $rawgfdlsections  = $matchedhash{rawgfdlsections}  || '';
    my $rawcontextbefore = $matchedhash{rawcontextbefore} || '';

    # strip puntuation
    my $gfdlsections  = _strip_punct($rawgfdlsections);
    my $contextbefore = _strip_punct($rawcontextbefore);

    # remove classical and without meaning part of
    # matched string
    $gfdlsections =~ s{
                          \A version \s \d+(?:\.\d+)? \s
                           (?:or \s any \s later \s version \s)?
                           published \s by \s the \s Free \s Software \s Foundation
                           \s?[,\.;]?\s?}{}xismo;
    $contextbefore =~ s{
                          \s? (:?[,\.;]? \s?)?
                           permission \s is \s granted \s to \s copy \s?[,\.;]?\s?
                           distribute \s?[,\.;]?\s? and\s?/?\s?or \s modify \s
                           this \s document \s under \s the \s terms \s of \s the\Z}
                        {}xismo;

    # Treat ambiguous empty text
    if ($gfdlsections eq '') {
        tag 'license-problem-gfdl-invariants-empty', $name;
        return 1;
    }

    # GFDL license, assume it is bad unless it
    # explicitly states it has no "bad sections".
    if (
        $gfdlsections =~ m/
                            no \s? Invariant \s+ Sections? \s? [,\.;]?
                               \s? (?:with\s)? (?:the\s)? no \s
                               Front(?:\s?\\?-)?\s?Cover (?:\s Texts?)? \s? [,\.;]? \s? (?:and\s)?
                               (?:with\s)? (?:the\s)? no
                               \s Back(?:\s?\\?-)?\s?Cover/xiso
      ){
        # no invariant
    }elsif (
        $gfdlsections =~ m/
                            no \s Invariant \s Sections? \s? [,\.;]?
                               \s? (?:no\s)? Front(?:\s?[\\]?-)? \s or
                               \s (?:no\s)? Back(?:\s?[\\]?-)?\s?Cover \s Texts?/xiso
      ){
        # no invariant variant (dict-foldoc)
    }elsif (
        $gfdlsections =~ m/
                            \A There \s are \s no \s invariants? \s sections? \Z
                          /xiso
      ){
        # no invariant libnss-pgsql version
    }elsif (
        $gfdlsections =~ m/
                            \A without \s any \s Invariant \s Sections? \Z
                          /xiso
      ){
        # no invariant parsewiki version
    }elsif (
        $gfdlsections =~ m/
                            \A with \s no \s invariants? \s sections? \Z
                         /xiso
      ){
        # no invariant lilypond version
    }elsif (
        $gfdlsections =~ m/\A
                            with \s the \s Invariant \s Sections \s being \s
                            LIST (?:\s THEIR \s TITLES)? \s? [,\.;]? \s?
                            with \s the \s Front(?:\s?[\\]?-)\s?Cover \s Texts \s being \s
                            LIST (?:\s THEIR \s TITLES)? \s? [,\.;]? \s?
                            (?:and\s)? with \s the \s Back(?:\s?[\\]?-)\s?Cover \s Texts \s being \s
                            LIST (?:\s THEIR \s TITLES)? \Z/xiso
      ){
        # verbatim text of license is ok
    }elsif (
        $gfdlsections =~ m/
                            with \s \&FDLInvariantSections; \s? [,\.;]? \s?
                            with \s+\&FDLFrontCoverText; \s? [,\.;]? \s?
                            and \s with \s \&FDLBackCoverText;/xiso
      ){
        # fix #708957 about FDL entities in template
        unless (
            $name =~ m{
                                /customization/[^/]+/entities/[^/]+\.docbook \Z
                              }xsm
          ){
            tag 'license-problem-gfdl-invariants', $name;
            return 1;
        }
    }elsif (
        $gfdlsections =~ m{
                            \A with \s the \s? <_: \s? link-\d+ \s? /> \s?
                            being \s list \s their \s titles \s?[,\.;]?\s?
                            with \s the \s? <_: \s* link-\d+ \s? /> \s?
                            being \s list \s?[,\.;]?\s?
                            (?:and\s)? with \s the \s? <_:\s? link-\d+ \s? /> \s?
                            being \s list \Z}xiso
      ){
        # fix a false positive in .po file
        unless ($name =~ m,\.po$,) {
            tag 'license-problem-gfdl-invariants', $name;
            return 1;
        }
    }else {
        if (
            $contextbefore =~ m/
                                  Following \s is \s an \s example
                                  (:?\s of \s the \s license \s notice \s to \s use
                                    (?:\s after \s the \s copyright \s (?:line(?:\(s\)|s)?)?
                                      (?:\s using \s all \s the \s features? \s of \s the \s GFDL)?
                                    )?
                                  )? \s? [,:]? \Z/xiso
          ){
            # it is an example
        }else {
            tag 'license-problem-gfdl-invariants', $name;
            return 1;
        }
    }
    return 0;
}

sub _clean_block {
    my ($text) = @_;

    # be paranoiac replace gnu with texinfo by gnu
    $text =~ s{
                 (?:@[[:alpha:]]*?\{)?\s*gnu\s*\}                   # Tex info cmd
             }{ gnu }gxms;

    # pod2man formating
    $text =~ s{ \\ \* \( [LR] \" }{\"}gxsm;

    # replace some common comment-marker/markup with space
    $text =~ s{(?:
                  ^\.\\\"                      |  # man comments
                  \@c(?:omment)?\s+            |  # Tex info comment
                  \@(?:b|i|r|t)\{              |  # Tex info bold, italic, roman, fixed width
                  \@(?:sansserif|slanted)\{    |  # Tex info sans serif/slanted
                  \@var\{                      |  # Tex info emphasis
                  \@(?:small)?example\s+       |  # Tex info example
                  \@end\h+(?:small)example\s+  |  # Tex info end small example tag
                  \@group\s+                   |  # Tex info group
                  \@end\h+group\s+             |  # Tex info end group
                  \}                           |  # Tex info end tag (could be more clever but brute force is fast)
                  \"\s*,                       |  # String array (e.g. "line1",\n"line2")
                  ,\s*\"                       |  # String array (e.g. "line1"\n ,"line2"), seen in findutils
                  <br\s*/?>                    |  # (X)HTML line breaks
                  <!--                         |  # XML comment
                  -->                          |  # end XML comment
                  </?link[^>]*?>               |  # xml link
                  </?a[^>]*?>                  |  # a link
                  </?citetitle[^>]*?>          |  # citation title in docbook
                  </?div[^>]*?>                |  # html style
                  </?p[^>]*?>                  |  # html paragraph
                  </?span[^>]*?>               |  # span tag
                  </?var[^>]*?>                |  # var tag used by html from texinfo
                  ^[-\+!<>]                    |  # diff/patch lines (should be after html tag)
                  \(\*note.*?::\)              |  # info file note
                  \\n                          |  # Verbatim \n in string array
                  \\&                          |  # pod2man formating
                  \\s(?:0|-1)                  |  # pod2man formating
                  (?:``|'')                    |  # quote like
                  [%\*\"\|\\\#]                   # String, C-style comment/javadoc indent,
                                                  # quotes for strings, pipe and antislash in some txt
                                                  # shell or po file comments
           )}{ }gxms;

    # delete double spacing now and normalize spacing
    # to space character
    $text =~ s{\s++}{ }gsm;
    strip($text);

    return $text;
}

# strip punctuation at both ends
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
    strip($text);

    return $text;
}

sub lc_block {
    return $_ = lc($_);
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

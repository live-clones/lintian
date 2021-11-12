# debian/watch -- lintian check script -*- perl -*-
#
# Copyright © 2008 Patrick Schoenfeld
# Copyright © 2008 Russ Allbery
# Copyright © 2008 Raphael Geissert
# Copyright © 2019 Felix Lechner
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

package Lintian::Check::Debian::Watch;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any firstval firstres);
use Path::Tiny;

use Lintian::Util qw($PKGREPACK_REGEX);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

const my $URL_ACTION_FIELDS => 4;
const my $VERSION_ACTION_FIELDS => 3;

const my $DMANGLES_AUTOMATICALLY => 4;

sub source {
    my ($self) = @_;

    my $file = $self->processable->patched->resolve_path('debian/watch');
    unless ($file && $file->is_file) {
        $self->hint('debian-watch-file-is-missing')
          unless $self->processable->native;
        return;
    }

    # Perform the other checks even if it is a native package
    $self->hint('debian-watch-file-in-native-package')
      if $self->processable->native;

    # Check if the Debian version contains anything that resembles a repackaged
    # source package sign, for fine grained version mangling check
    # If the version field is missing, we assume a neutral non-native one.

    # upstream method returns empty for native packages
    my $upstream = $self->processable->changelog_version->upstream;
    my ($prerelease) = ($upstream =~ qr/(alpha|beta|rc)/i);

# there is a good repack indicator in $processable->repacked but we need the text
    my ($repack) = ($upstream =~ $PKGREPACK_REGEX);

    return
      unless $file->is_open_ok;

    my $contents = $file->bytes;

    # each pattern marks a multi-line (!) selection for the tag message
    my @templatepatterns
      = (qr/^\s*#\s*(Example watch control file for uscan)/mi,qr/(<project>)/);
    my $templatestring;

    for my $pattern (@templatepatterns) {
        ($templatestring) = ($contents =~ $pattern);
        last if defined $templatestring;
    }

    $self->hint('debian-watch-contains-dh_make-template', $templatestring)
      if length $templatestring;

    # remove backslash at end; uscan will catch it
    $contents =~ s/(?<!\\)\\$//;

    my $standard;

    my @lines = split(/\n/, $contents);

    # look for watch file version
    for my $line (@lines) {

        if ($line =~ /^\s*version\s*=\s*(\d+)\s*$/) {
            if (length $1) {
                $standard = $1;
                last;
            }
        }
    }

    return
      unless defined $standard;

    # version 1 too broken to check
    return
      if $standard < 2;

    # allow spaces for all watch file versions (#950250, #950277)
    my $separator = qr/\s*,\s*/;

    my @errors;
    my $withgpgverification = 0;
    my %dversions;

    my $position = 1;
    my $continued = $EMPTY;
    for my $line (@lines) {

        # strip leading spaces
        $line =~ s/^\s*//;

        # strip comments, if any
        $line =~ s/^\#.*$//;

        unless (length $line) {
            $continued = $EMPTY;
            next;
        }

        # merge continuation lines
        if ($line =~ s/\\$//) {
            $continued .= $line;
            next;
        }

        $line = $continued . $line
          if length $continued;

        $continued = $EMPTY;

        next
          if $line =~ /^version\s*=\s*\d+\s*$/;

        my $remainder = $line;

        my @options;

        # keep order; otherwise. alternative \S+ ends up with quotes
        if ($remainder =~ s/opt(?:ion)?s=(?|\"((?:[^\"]|\\\")+)\"|(\S+))\s+//){
            @options = split($separator, $1);
        }

        unless (length $remainder) {
            push(@errors, $line);
            next;
        }

        my $repack_mangle = 0;
        my $repack_dmangle = 0;
        my $repack_dmangle_auto = 0;
        my $prerelease_mangle = 0;
        my $prerelease_umangle = 0;

        for my $option (@options) {

            if (length $repack) {
                $repack_mangle = 1
                  if $option
                  =~ /^[ud]?versionmangle\s*=\s*(?:auto|.*$repack.*)/;
                $repack_dmangle = 1
                  if $option =~ /^dversionmangle\s*=\s*(?:auto|.*$repack.*)/;
            }

            if (length $prerelease) {
                $prerelease_mangle = 1
                  if $option =~ /^[ud]?versionmangle\s*=.*$prerelease/;
                $prerelease_umangle = 1
                  if $option =~ /^uversionmangle\s*=.*$prerelease/;
            }

            $repack_dmangle_auto = 1
              if $option =~ /^dversionmangle\s*=.*(?:s\/\@DEB_EXT\@\/|auto)/
              && $standard >= $DMANGLES_AUTOMATICALLY;

            $withgpgverification = 1
              if $option =~ /^pgpsigurlmangle\s*=\s*/
              || $option =~ /^pgpmode\s*=\s*(?!none\s*$)\S.*$/;

            my ($name, $value) = split(m{ \s* = \s* }x, $option, 2);

            next
              unless length $name;

            $value //= $EMPTY;

            $self->hint('prefer-uscan-symlink', $name, $value,
                "[debian/watch:$position]")
              if $name eq 'filenamemangle';
        }

        $self->hint('debian-watch-file-uses-deprecated-sf-redirector-method',
            $remainder)
          if $remainder =~ m{qa\.debian\.org/watch/sf\.php\?};

        $self->hint('debian-watch-file-uses-deprecated-githubredir',$remainder)
          if $remainder =~ m{githubredir\.debian\.net};

        $self->hint('debian-watch-lacks-sourceforge-redirector', $remainder)
          if $remainder =~ m{ (?:https?|ftp)://
                              (?:(?:.+\.)?dl|(?:pr)?downloads?|ftp\d?|upload) \.
                              (?:sourceforge|sf)\.net}xsm
          || $remainder =~ m{https?://(?:www\.)?(?:sourceforge|sf)\.net
                                                   /project/showfiles\.php}xsm
          || $remainder =~ m{https?://(?:www\.)?(?:sourceforge|sf)\.net
                  /projects/.+/files}xsm;

        $self->hint('debian-watch-uses-insecure-uri', $1, "(line $position)")
          if $remainder =~ m{((?:http|ftp):(?!//sf.net/)\S+)};

        # This bit is as-is from uscan.pl:
        my ($base, $filepattern, $lastversion, $action)
          = split($SPACE, $remainder, $URL_ACTION_FIELDS);

        # Per #765995, $base might be undefined.
        if (defined $base) {
            if ($base =~ s{/([^/]*\([^/]*\)[^/]*)$}{/}) {
               # Last component of $base has a pair of parentheses, so no
               # separate filepattern field; we remove the filepattern from the
               # end of $base and rescan the rest of the line
                $filepattern = $1;
                (undef, $lastversion, $action)
                  = split($SPACE, $remainder, $VERSION_ACTION_FIELDS);
            }

            $dversions{$lastversion} = 1
              if defined $lastversion;

            $lastversion = 'debian'
              unless defined $lastversion;
        }

        # If the version of the package contains dfsg, assume that it needs
        # to be mangled to get reasonable matches with upstream.
        my $needs_repack_mangling = ($repack && $lastversion eq 'debian');
        $self->hint('debian-watch-not-mangling-version', $line)
          if $needs_repack_mangling
          && !$repack_mangle
          && !$repack_dmangle_auto;

        $self->hint('debian-watch-mangles-debian-version-improperly',$line)
          if $needs_repack_mangling
          && $repack_mangle
          && !$repack_dmangle;

        my $needs_prerelease_mangling
          = ($prerelease && $lastversion eq 'debian');
        $self->hint('debian-watch-mangles-upstream-version-improperly',$line)
          if $needs_prerelease_mangling
          && $prerelease_mangle
          && !$prerelease_umangle;

        my $upstream_url = $remainder;

        # Keep only URL part
        $upstream_url =~ s/(.*?\S)\s.*$/$1/;

        for my $option (@options) {
            if ($option =~ /^ component = (.+) $/x) {
                my $component = $1;
                $self->hint('debian-watch-upstream-component',
                    $upstream_url, $component, "(line $position)");
            }
        }

    } continue {
        ++$position;
    }

    $self->hint('debian-watch-line-invalid', $_)for @errors;

    $self->hint('debian-watch-does-not-check-gpg-signature')
      unless $withgpgverification;

    my $SIGNING_KEY_FILENAMES
      = $self->profile->load_data('common/signing-key-filenames');

    # look for upstream signing key
    my @candidates
      = map { $self->processable->patched->resolve_path("debian/$_") }
      $SIGNING_KEY_FILENAMES->all;
    my $keyfile = firstval {$_ && $_->is_file} @candidates;

    # check upstream key is present if needed
    $self->hint('debian-watch-file-pubkey-file-is-missing')
      if $withgpgverification && !$keyfile;

    # check upstream key is used if present
    $self->hint('debian-watch-could-verify-download', $keyfile->name)
      if $keyfile && !$withgpgverification;

    if (defined $self->processable->changelog && %dversions) {

        my %changelog_versions;
        my $count = 1;
        my $changelog = $self->processable->changelog;
        for my $entry (@{$changelog->entries}) {
            my $uversion = $entry->Version;
            $uversion =~ s/-[^-]+$//; # revision
            $uversion =~ s/^\d+://; # epoch
            $changelog_versions{'orig'}{$entry->Version} = $count;

            # Preserve the first value here to correctly detect old versions.
            $changelog_versions{'mangled'}{$uversion} = $count
              unless (exists($changelog_versions{'mangled'}{$uversion}));
            $count++;
        }

        for my $dversion (sort keys %dversions) {
            next
              if $dversion eq 'debian';
            local $" = ', ';
            if (!$self->processable->native
                && exists($changelog_versions{'orig'}{$dversion})) {
                $self->hint(
                    'debian-watch-file-specifies-wrong-upstream-version',
                    $dversion);
                next;
            }
            if (exists $changelog_versions{'mangled'}{$dversion}
                && $changelog_versions{'mangled'}{$dversion} != 1) {
                $self->hint('debian-watch-file-specifies-old-upstream-version',
                    $dversion);
                next;
            }
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

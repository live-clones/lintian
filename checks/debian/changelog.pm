# debian/changelog -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2017 Chris Lamb <lamby@debian.org>
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

package Lintian::debian::changelog;

use strict;
use warnings;
use autodie;

use Date::Format qw(time2str);
use Email::Valid;
use Encode qw(decode);
use List::Util qw(first);
use List::MoreUtils qw(any uniq);
use Path::Tiny;
use Try::Tiny;

use Lintian::Data ();
use Lintian::Inspect::Changelog;
use Lintian::Inspect::Changelog::Version;
use Lintian::Relation::Version qw(versions_gt);
use Lintian::Spelling qw(check_spelling);
use Lintian::Util qw(file_is_encoded_in_non_utf8 strip);

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $BUGS_NUMBER
  = Lintian::Data->new('changelog-file/bugs-number', qr/\s*=\s*/o);
my $INVALID_DATES
  = Lintian::Data->new('changelog-file/invalid-dates', qr/\s*=\>\s*/o);

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->tag(@orig_args, @_);
    };
}

sub source {
    my ($self) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;
    my $group = $self->group;

    my @entries = @{$processable->changelog->entries};

    return
      unless @entries;

    my $latest_entry = $entries[0];

    my $changes = $group->changes;
    if ($changes) {
        my $contents = path($changes->path)->slurp;
        # make sure dot matches newlines, as well
        if ($contents =~ qr/BEGIN PGP SIGNATURE.*END PGP SIGNATURE/ms) {

            $self->tag('unreleased-changelog-distribution')
              if $latest_entry->Distribution eq 'UNRELEASED';
        }
    }

    my $versionstring = $processable->field('version', EMPTY);
    my $latest_version = Lintian::Inspect::Changelog::Version->new;

    try {
        $latest_version->set($versionstring, $processable->native);

    } catch {
        my $indicator= ($processable->native ? EMPTY : 'non-') . 'native';
        $self->tag(
            'malformed-debian-changelog-version',
            $versionstring . " (for $indicator)"
        );
        undef $latest_version;
    };

    if (defined $latest_version) {

        $self->tag('hyphen-in-upstream-part-of-debian-changelog-version',
            $latest_version->upstream)
          if !$processable->native && $latest_version->upstream =~ qr/-/;

        # unstable, testing, and stable shouldn't be used in Debian
        # version numbers.  unstable should get a normal version
        # increment and testing and stable should get suite-specific
        # versions.
        #
        # NMUs get a free pass because they need to work with the
        # version number that was already there.
        unless (length $latest_version->source_nmu) {
            my $revision = $latest_version->maintainer_revision;
            my $distribution = $latest_entry->Distribution;

            $self->tag('version-refers-to-distribution',
                $latest_version->literal)
              if ($revision =~ /testing|(?:un)?stable/i)
              || (
                ($distribution eq 'unstable'|| $distribution eq 'experimental')
                && $revision
                =~ /woody|sarge|etch|lenny|squeeze|stretch|buster/);
        }

        my $examine = $latest_version->maintainer_revision;
        $examine = $latest_version->upstream
          unless $processable->native;

        my $candidate_pattern = qr/rc|alpha|beta|pre(?:view|release)?/;
        my $increment_pattern = qr/[^a-z].*|\Z/;

        my ($candidate_string, $increment_string)
          = ($examine =~ m/[^~a-z]($candidate_pattern)($increment_pattern)/sm);
        if (length $candidate_string && !length $latest_version->source_nmu) {

            my $increment_string //= EMPTY;

            # remove rc-part and any preceding symbol
            my $expected = $examine;
            $expected =~ s/[\.\+\-\:]?\Q$candidate_string\E.*//;

            my $suggestion = "$expected~$candidate_string$increment_string";

            $self->tag(
                'rc-version-greater-than-expected-version',
                $examine, '>',$expected, "(consider using $suggestion)",
              )
              if $latest_version->maintainer_revision eq '1'
              || $latest_version->maintainer_revision=~ m,^0(?:\.1|ubuntu1)?$,
              || $processable->native;
        }
    }

    if (@entries > 1) {

        my $previous_entry = $entries[1];
        my $latest_timestamp = $latest_entry->Timestamp;
        my $previous_timestamp = $previous_entry->Timestamp;

        my $previous_version = Lintian::Inspect::Changelog::Version->new;
        try {
            $previous_version->set($previous_entry->Version,
                $processable->native);
        } catch {
            my $indicator= ($processable->native ? EMPTY : 'non-') . 'native';
            $self->tag(
                'odd-historical-debian-changelog-version',
                $previous_entry->Version . " (for $indicator)"
            );
            undef $previous_version;
        };

        if ($latest_timestamp && $previous_timestamp) {
            $self->tag('latest-debian-changelog-entry-without-new-date')
              unless ($latest_timestamp - $previous_timestamp) > 0
              || lc($latest_entry->Distribution) eq 'unreleased';
        }

        if (defined $latest_version) {
            foreach my $entry (@entries[1..$#entries]) {

                # cannot use parser; nativeness may differ
                my ($no_epoch) = ($entry->Version =~ qr/^(?:[^:]+:)?([^:]+)$/);

                next
                  unless defined $no_epoch;

                # disallowed even if epochs differ; see tag description
                if (   $latest_version->no_epoch eq $no_epoch
                    && $latest_entry->Source eq $entry->Source) {
                    $self->tag(
'latest-debian-changelog-entry-reuses-existing-version',
                        $latest_version->literal. ' ~= '
                          . $entry->Version
                          . ' (last used: '
                          . $entry->Date . ')'
                    );
                    last;
                }
            }
        }

        if (defined $latest_version && defined $previous_version) {

            # a reused version literal is caught by the broader previous check

            # start with a reasonable default
            my $expected_previous = $previous_version->literal;

            $expected_previous = $latest_version->without_backport
              if $latest_version->backport_release
              && $latest_version->backport_revision
              && $latest_version->debian_without_backport ne '0';

            # find an appropriate prior version for a source NMU
            if (length $latest_version->source_nmu) {

                # can only do first nmu for now
                $expected_previous = $latest_version->without_source_nmu
                  if $latest_version->source_nmu eq '1'
                  &&$latest_version->maintainer_revision =~ qr/\d+/
                  && $latest_version->maintainer_revision ne '0';
            }

            $self->tag('changelog-file-missing-explicit-entry',
                    $previous_version->literal
                  . " -> $expected_previous (missing) -> "
                  . $latest_version->literal)
              unless $previous_version->literal eq $expected_previous
              || $latest_entry->Distribution eq 'buster'
              || $previous_entry->Distribution eq 'buster'
              || $latest_entry->Distribution =~ /-security$/i;

            if (   $latest_version->epoch eq $previous_version->epoch
                && $latest_version->upstream eq$previous_version->upstream
                && $latest_entry->Source eq $previous_entry->Source
                && !$processable->native) {

                $self->tag('possible-new-upstream-release-without-new-version')
                  if $latest_entry->Changes
                  =~ /^\s*\*\s+new\s+upstream\s+(?:\S+\s+)?release\b/im;

                my $latest = $latest_version->maintainer_revision;
                my $previous = $previous_version->maintainer_revision;
                $self->tag('non-consecutive-debian-revision',
                        $previous_version->literal . ' -> '
                      . $latest_version->literal)
                  if $previous =~ /^\d+$/
                  and $latest =~ /^\d+$/
                  and $latest != $previous + 1;
            }

            if ($latest_version->epoch ne $previous_version->epoch) {
                $self->tag('epoch-change-without-comment',
                        $previous_version->literal . ' -> '
                      . $latest_version->literal)
                  unless $latest_entry->Changes =~ /\bepoch\b/im;

                $self->tag(
                    'epoch-changed-but-upstream-version-did-not-go-backwards',
                    $previous_version->literal . ' -> '
                      . $latest_version->literal
                  )
                  unless $processable->native
                  || versions_gt($previous_version->upstream,
                    $latest_version->upstream);
            }
        }
    }

    return;
}

sub binary {
    my ($self) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;
    my $group = $self->group;

    my $found_html = 0;
    my $found_text = 0;
    my ($native_pkg, $foreign_pkg, @doc_files);

    # skip packages which have a /usr/share/doc/$pkg -> foo symlink
    return
      if  $processable->installed->lookup("usr/share/doc/$pkg")
      and $processable->installed->lookup("usr/share/doc/$pkg")->is_symlink;

    if (my $docdir = $processable->installed->lookup("usr/share/doc/$pkg/")) {
        for my $path ($docdir->children) {
            my $basename = $path->basename;

            next unless $path->is_file or $path->is_symlink;

            push(@doc_files, $basename);

            # Check a few things about the NEWS.Debian file.
            if ($basename =~ m{\A NEWS\.Debian (?:\.gz)? \Z}ixsm) {
                if ($basename !~ m{ \.gz \Z }xsm) {
                    $self->tag('debian-news-file-not-compressed', $path->name);
                } elsif ($basename ne 'NEWS.Debian.gz') {
                    $self->tag('wrong-name-for-debian-news-file', $path->name);
                }
            }

            # Check if changelog files are compressed with gzip -9.
            # It's a bit of an open question here what we should do
            # with a file named ChangeLog.  If there's also a
            # changelog file, it might be a duplicate, or the packager
            # may have installed NEWS as changelog intentionally.
            next
              unless $basename =~ m{\A changelog (?:\.html|\.Debian)?
                                       (?:\.gz)? \Z}xsm;

            if ($basename !~ m{ \.gz \Z}xsm) {
                $self->tag('changelog-file-not-compressed', $basename);
            } else {
                my $max_compressed = 0;
                my $file_info = $path->file_info;
                if ($path->is_symlink) {
                    my $normalized = $path->link_normalized;
                    if (defined($normalized)) {
                        $file_info = $path->file_info;
                    }
                }
                if (defined($file_info)) {
                    if (index($file_info, 'max compression') != -1) {
                        $max_compressed = 1;
                    }
                    if (not $max_compressed
                        and index($file_info, 'gzip compressed') != -1) {
                        $self->tag(
                            'changelog-not-compressed-with-max-compression',
                            $basename);
                    }
                }
            }

            if (   $basename eq 'changelog.html'
                or $basename eq 'changelog.html.gz') {
                $found_html = 1;
            } elsif ($basename eq 'changelog' or $basename eq 'changelog.gz') {
                $found_text = 1;
            }
        }
    }

    # Check a NEWS.Debian file if we have one.  Save the parsed version of the
    # file for later checks against the changelog file.
    my $news;
    my $dnews = path($processable->groupdir)->child('NEWS.Debian')->stringify;
    if (-f $dnews) {
        my $line = file_is_encoded_in_non_utf8($dnews);
        if ($line) {
            $self->tag('debian-news-file-uses-obsolete-national-encoding',
                "at line $line");
        }
        my $changelog = Lintian::Inspect::Changelog->new;
        my $contents = path($dnews)->slurp;
        $changelog->parse($contents);

        if (my @errors = @{$changelog->errors}) {
            for (@errors) {
                $self->tag('syntax-error-in-debian-news-file',
                    "line $_->[0]","\"$_->[1]\"");
            }
        }

        # Some checks on the most recent entry.
        if ($changelog->entries && defined @{$changelog->entries}[0]) {
            ($news) = @{$changelog->entries};
            if ($news->Distribution && $news->Distribution eq 'UNRELEASED') {
                $self->tag('debian-news-entry-has-strange-distribution',
                    $news->Distribution);
            }
            check_spelling(
                $news->Changes,
                $group->spelling_exceptions,
                $self->spelling_tag_emitter('spelling-error-in-news-debian'));
            if ($news->Changes =~ /^\s*\*\s/) {
                $self->tag('debian-news-entry-uses-asterisk');
            }
        }
    }

    if ($found_html && !$found_text) {
        $self->tag('html-changelog-without-text-version');
    }

    # is this a native Debian package?
    # If the version is missing, we assume it to be non-native
    # as it is the most likely case.
    my $source = $processable->field('source');
    my $version;
    if (defined $source && $source =~ m/\((.*)\)/) {
        $version = $1;
    } else {
        $version = $processable->field('version');
    }
    if (defined $version) {
        $native_pkg = ($version !~ m/-/);
    } else {
        # We do not know, but assume it to non-native as it is
        # the most likely case.
        $native_pkg = 0;
    }
    $version = $processable->field('version', '0-1');
    $foreign_pkg = (!$native_pkg && $version !~ m/-0\./);
    # A version of 1.2.3-0.1 could be either, so in that
    # case, both vars are false

    if ($native_pkg) {
        # native Debian package
        if (any { m/^changelog(?:\.gz)?$/} @doc_files) {
            # everything is fine
        } elsif (
            my $chg = first {
                m/^changelog\.debian(?:\.gz)$/i;
            }
            @doc_files
        ) {
            $self->tag('wrong-name-for-changelog-of-native-package',
                "usr/share/doc/$pkg/$chg");
        } else {
            $self->tag('changelog-file-missing-in-native-package');
        }
    } else {
        # non-native (foreign :) Debian package

        # 1. check for upstream changelog
        my $found_upstream_text_changelog = 0;
        if (any { m/^changelog(\.html)?(?:\.gz)?$/ } @doc_files) {
            $found_upstream_text_changelog = 1 unless $1;
            # everything is fine
        } else {
            # search for changelogs with wrong file name
            for (@doc_files) {
                if (m/^change/i and not m/debian/i) {
                    $self->tag('wrong-name-for-upstream-changelog',
                        "usr/share/doc/$pkg/$_");
                    last;
                }
            }
        }

        # 2. check for Debian changelog
        if (any { m/^changelog\.Debian(?:\.gz)?$/ } @doc_files) {
            # everything is fine
        } elsif (
            my $chg = first {
                m/^changelog\.debian(?:\.gz)?$/i;
            }
            @doc_files
        ) {
            $self->tag('wrong-name-for-debian-changelog-file',
                "usr/share/doc/$pkg/$chg");
        } else {
            if ($foreign_pkg && $found_upstream_text_changelog) {
                $self->tag('debian-changelog-file-missing-or-wrong-name');
            } elsif ($foreign_pkg) {
                $self->tag('debian-changelog-file-missing');
            }
            # TODO: if uncertain whether foreign or native, either
            # changelog.gz or changelog.debian.gz should exists
            # though... but no tests catches this (extremely rare)
            # border case... Keep in mind this is only happening if we
            # have a -0.x version number... So not my priority to fix
            # --Jeroen
        }
    }

    my $dchpath = path($processable->groupdir)->child('changelog')->stringify;
    # Everything below involves opening and reading the changelog file, so bail
    # with a warning at this point if all we have is a symlink.  Ubuntu permits
    # such symlinks, so their profile will suppress this tag.
    if (-l $dchpath) {
        $self->tag('debian-changelog-file-is-a-symlink');
        return;
    }

    # Bail at this point if the changelog file doesn't exist.  We will have
    # already warned about this.
    unless (-f $dchpath) {
        return;
    }

    # check that changelog is UTF-8 encoded
    my $line = file_is_encoded_in_non_utf8($dchpath);
    if ($line) {
        $self->tag('debian-changelog-file-uses-obsolete-national-encoding',
            "at line $line");
    }

    my $changelog = $processable->changelog;
    if (my @errors = @{$changelog->errors}) {
        foreach (@errors) {
            $self->tag('syntax-error-in-debian-changelog',
                "line $_->[0]","\"$_->[1]\"");
        }
    }

    # Check for some things in the raw changelog file and compute the
    # "offset" to the first line of the first entry.  We use this to
    # report the line number of "too-long" lines.  (#657402)
    my $chloff = $self->check_dch($dchpath);

    my @entries = @{$changelog->entries};

    # all versions from the changelog
    my %allversions
      = map { $_ => 1 } grep { defined $_ } map { $_->Version } @entries;

    # checks applying to all entries
    for my $entry (@entries) {
        if (length $entry->Maintainer) {
            my ($email) = ($entry->Maintainer =~ qr/<([^>]*)>/);

           # cannot use Email::Valid->tld to check for dot until this is fixed:
           # https://github.com/Perl-Email-Project/Email-Valid/issues/38
            $self->tag('debian-changelog-file-contains-invalid-email-address',
                $email)
              unless Email::Valid->rfc822($email) && $email =~ qr/\.[^.@]+$/;
        }
    }

    if (@entries) {

        # checks related to the latest entry
        my $latest_entry = $entries[0];

        my $latest_timestamp = $latest_entry->Timestamp;

        if ($latest_timestamp) {
            my $warned = 0;
            my $longdate = $latest_entry->Date;
            foreach my $re ($INVALID_DATES->all()) {
                if ($longdate =~ m/($re)/i) {
                    my $repl = $INVALID_DATES->value($re);
                    $self->tag('invalid-date-in-debian-changelog',
                        "($1 -> $repl)");
                    $warned = 1;
                }
            }
            my ($weekday_declared, $numberportion)
              = split(m/,\s*/, $longdate, 2);
            $numberportion //= EMPTY;
            my ($tz, $weekday_actual);

            if ($numberportion =~ m/[ ]+ ([^ ]+)\Z/xsm) {
                $tz = $1;
                $weekday_actual = time2str('%a', $latest_timestamp, $tz);
            }
            if (not $warned and $tz and $weekday_declared ne $weekday_actual) {
                my $real_weekday = time2str('%A', $latest_timestamp, $tz);
                my $short_date = time2str('%Y-%m-%d', $latest_timestamp, $tz);
                $self->tag('debian-changelog-has-wrong-day-of-week',
                    "$short_date is a $real_weekday");
            }
        }

        # there is more than one changelog entry
        if (@entries > 1) {

            my $previous_entry = $entries[1];

            my $previous_timestamp = $previous_entry->Timestamp;

            if ($latest_timestamp && $previous_timestamp) {
                $self->tag('latest-changelog-entry-without-new-date')
                  unless (($latest_timestamp - $previous_timestamp) > 0
                    or $latest_entry->Distribution eq 'UNRELEASED');
            }

            my $latest_dist = lc $latest_entry->Distribution;
            my $previous_dist = lc $previous_entry->Distribution;
            if (    $latest_dist eq 'unstable'
                and $previous_dist eq 'experimental') {
                unless ($latest_entry->Changes
                    =~ /\bto\s+['"‘“]?(?:unstable|sid)['"’”]?\b/im) {
                    $self->tag('experimental-to-unstable-without-comment');
                }
            }

            my $changes = $group->changes;
            if ($changes) {
                my $changes_dist= lc($changes->field('distribution', EMPTY));

                my %codename;
                $codename{'unstable'} = 'sid';
                my @normalized
                  = map { $codename{$_} // $_ }($latest_dist, $changes_dist);

                $self->tag(
                    'changelog-distribution-does-not-match-changes-file',
                    "($latest_dist != $changes_dist)")
                  unless scalar(uniq @normalized) == 1;
            }

        }

        # Some checks should only be done against the most recent
        # changelog entry.
        my $changes = $latest_entry->Changes || EMPTY;

        if (@entries == 1) {
            if ($latest_entry->Version and $latest_entry->Version =~ /-1$/) {
                $self->tag('new-package-should-close-itp-bug')
                  unless @{ $latest_entry->Closes };
            }
            $self->tag('changelog-is-dh_make-template')
              if $changes
              =~ /(?:#?\s*)(?:\d|n)+ is the bug number of your ITP/i;
        }
        while ($changes =~ /(closes\s*(?:bug)?\#?\s?\d{6,})[^\w]/ig) {
            $self->tag('possible-missing-colon-in-closes', $1) if $1;
        }
        if ($changes =~ m/(TEMP-\d{7}-[0-9a-fA-F]{6})/) {
            $self->tag('changelog-references-temp-security-identifier', $1);
        }

        # check for bad intended distribution
        if (
            $changes =~ /uploads? \s+ to \s+
                            (?'intended'testing|unstable|experimental|sid)/xi
        ){
            my $intended = lc($+{intended});
            if($intended eq 'sid') {
                $intended = 'unstable';
            }
            my $uploaded = $latest_entry->Distribution;
            unless ($uploaded eq 'UNRELEASED') {
                unless($uploaded eq $intended) {
                    $self->tag('bad-intended-distribution',
                        "intended to $intended but uploaded to $uploaded");
                }
            }
        }

        if($changes =~ /Close:\s+(\#\d+)/xi) {
            $self->tag('misspelled-closes-bug',$1);
        }

        my $changesempty = $changes;
        $changesempty =~ s,\W,,gms;
        if (length($changesempty)==0) {
            $self->tag('changelog-empty-entry')
              unless $latest_entry->Distribution eq 'UNRELEASED';
        }

        # before bug 50004 bts removed bug instead of archiving
        for my $bug (@{$latest_entry->Closes}) {
            $self->tag('improbable-bug-number-in-closes', $bug)
              if $bug < $BUGS_NUMBER->value('min-bug')
              || $bug > $BUGS_NUMBER->value('max-bug');
        }

        # Compare against NEWS.Debian if available.
        if ($news and $news->Version) {
            if ($latest_entry->Version eq $news->Version) {
                for my $field (qw/Distribution Urgency/) {
                    if ($latest_entry->$field ne $news->$field) {
                        $self->tag('changelog-news-debian-mismatch',
                            lc($field),
                            $latest_entry->$field . ' != ' . $news->$field);
                    }
                }
            }
            unless (exists $allversions{$news->Version}) {
                $self->tag('debian-news-entry-has-unknown-version',
                    $news->Version);
            }
        }

        # We have to decode into UTF-8 to get the right length for the
        # length check.  For some reason, use open ':utf8' isn't
        # sufficient.  If the changelog uses a non-UTF-8 encoding,
        # this will mangle it, but it doesn't matter for the length
        # check.
        #
        # Parse::DebianChangelog adds an additional space to the
        # beginning of each line, so we have to adjust for that in the
        # length check.
        my @lines = split("\n", decode('utf-8', $changes));
        for my $i (0 .. $#lines) {
            my $line = $i + $chloff;
            $self->tag('debian-changelog-line-too-short', $1, "(line $line)")
              if $lines[$i] =~ /^   [*]\s(.{1,5})$/ and $1 !~ /:$/;
            if (length($lines[$i]) > 81
                and $lines[$i] !~ /^[\s.o*+-]*(?:[Ss]ee:?\s+)?\S+$/) {
                $self->tag('debian-changelog-line-too-long', "line $line");
            }
        }

        # Strip out all lines that contain the word spelling to avoid false
        # positives on changelog entries for spelling fixes.
        $changes =~ s/^.*(?:spelling|typo).*\n//gm;
        check_spelling(
            $changes,
            $group->spelling_exceptions,
            $self->spelling_tag_emitter('spelling-error-in-changelog'));
    }

    return;
}

# read the changelog itself and check for some issues we cannot find
# with Parse::DebianChangelog.  Also return the "real" line number for
# the first line of text in the first entry.
#
sub check_dch {
    my ($self, $path) = @_;

    # emacs only looks at the last "local variables" in a file, and only at
    # one within 3000 chars of EOF and on the last page (^L), but that's a bit
    # pesky to replicate.  Demanding a match of $prefix and $suffix ought to
    # be enough to avoid false positives.

    my ($prefix, $suffix);
    my $lineno = 0;
    my ($estart, $tstart) = (0, 0);
    open(my $fd, '<', $path);
    while (<$fd>) {

        unless ($tstart) {
            $lineno++;
            $estart = 1 if m/^\S/;
            $tstart = 1 if m/^\s+\S/;
        }

        if (
               m/closes:\s*(((?:bug)?\#?\s?\d*)[[:alpha:]]\w*)/io
            || m/closes:\s*(?:bug)?\#?\s?\d+
              (?:,\s*(?:bug)?\#?\s?\d+)*
              (?:,\s*(((?:bug)?\#?\s?\d*)[[:alpha:]]\w*))/iox
        ) {
            $self->tag('wrong-bug-number-in-closes', "l$.:$1") if $2;
        }

        if (/^(.*)Local\ variables:(.*)$/i) {
            $prefix = $1;
            $suffix = $2;
        }
        # emacs allows whitespace between prefix and variable, hence \s*
        if (   defined $prefix
            && defined $suffix
            && m/^\Q$prefix\E\s*add-log-mailing-address:.*\Q$suffix\E$/) {
            $self->tag(
                'debian-changelog-file-contains-obsolete-user-emacs-settings');
        }
    }
    close($fd);
    return $lineno;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# debian/changelog -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2019-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Debian::Changelog;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Data::Validate::Domain;
use Date::Format qw(time2str);
use Email::Address::XS;
use List::Util qw(first);
use List::SomeUtils qw(any all uniq);
use Path::Tiny;
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::Changelog;
use Lintian::Changelog::Version;
use Lintian::IPC::Run3 qw(safe_qx);
use Lintian::Relation::Version qw(versions_gt);
use Lintian::Spelling qw(check_spelling);

const my $EMPTY => q{};
const my $DOUBLE_QUOTE => q{"};
const my $GREATER_THAN => q{>};
const my $APPROXIMATELY_EQUAL => q{~};

const my $NOT_EQUALS => q{!=};
const my $ARROW => q{->};

const my $MAXIMUM_WIDTH => 82;
const my $FIRST_ARCHIVED_BUG_NUMBER => 50_004;
const my $OUT_OF_REACH_BUG_NUMBER => 1_500_000;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub spelling_tag_emitter {
    my ($self, $tag_name, $item, @orig_args) = @_;

    my $pointer = $item->pointer($.);

    return sub {
        return $self->pointed_hint($tag_name, $pointer, @orig_args, @_);
    };
}

sub source {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;
    my $group = $self->group;

    my $changelog = $processable->changelog;
    return
      unless defined $changelog;

    my @entries = @{$changelog->entries};
    return
      unless @entries;

    my $latest_entry = $entries[0];

    my $changelog_item = $self->processable->changelog_item;
    my $latest_pointer = $changelog_item->pointer($latest_entry->position);

    my $changes = $group->changes;
    if ($changes) {
        my $contents = path($changes->path)->slurp;
        # make sure dot matches newlines, as well
        if ($contents =~ qr/BEGIN PGP SIGNATURE.*END PGP SIGNATURE/ms) {

            $self->pointed_hint('unreleased-changelog-distribution',
                $latest_pointer)
              if $latest_entry->Distribution eq 'UNRELEASED';
        }
    }

    my $versionstring = $processable->fields->value('Version');
    my $latest_version = Lintian::Changelog::Version->new;

    try {
        $latest_version->assign($versionstring, $processable->native);

    } catch {
        my $indicator= ($processable->native ? $EMPTY : 'non-') . 'native';
        $self->pointed_hint('malformed-debian-changelog-version',
            $latest_pointer,$versionstring, "(for $indicator)");
        undef $latest_version;

        # perlcritic 1.140-1 requires a semicolon on the next line
    };

    if (defined $latest_version) {

        $self->pointed_hint(
            'hyphen-in-upstream-part-of-debian-changelog-version',
            $latest_pointer,$latest_version->upstream)
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

            $self->pointed_hint('version-refers-to-distribution',
                $latest_pointer,$latest_version->literal)
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

            $increment_string //= $EMPTY;

            # remove rc-part and any preceding symbol
            my $expected = $examine;
            $expected =~ s/[\.\+\-\:]?\Q$candidate_string\E.*//;

            my $suggestion = "$expected~$candidate_string$increment_string";

            $self->pointed_hint(
                'rc-version-greater-than-expected-version',
                $latest_pointer,
                $examine,
                $GREATER_THAN,
                $expected,
                "(consider using $suggestion)",
              )
              if $latest_version->maintainer_revision eq '1'
              || $latest_version->maintainer_revision=~ /^0(?:\.1|ubuntu1)?$/
              || $processable->native;
        }
    }

    if (@entries > 1) {

        my $previous_entry = $entries[1];
        my $latest_timestamp = $latest_entry->Timestamp;
        my $previous_timestamp = $previous_entry->Timestamp;

        my $previous_version = Lintian::Changelog::Version->new;
        try {
            $previous_version->assign($previous_entry->Version,
                $processable->native);
        } catch {
            my $indicator= ($processable->native ? $EMPTY : 'non-') . 'native';
            $self->pointed_hint(
                'odd-historical-debian-changelog-version',
                $changelog_item->pointer($previous_entry->position),
                $previous_entry->Version,
                "(for $indicator)"
            );
            undef $previous_version;
        }

        if ($latest_timestamp && $previous_timestamp) {

            $self->pointed_hint(
                'latest-debian-changelog-entry-without-new-date',
                $latest_pointer)
              if $latest_timestamp <= $previous_timestamp
              && lc($latest_entry->Distribution) ne 'unreleased';
        }

        if (defined $latest_version) {

            # skip first
            for my $entry (@entries[1..$#entries]) {

                # cannot use parser; nativeness may differ
                my ($no_epoch) = ($entry->Version =~ qr/^(?:[^:]+:)?([^:]+)$/);

                next
                  unless defined $no_epoch;

                # disallowed even if epochs differ; see tag description
                if (   $latest_version->no_epoch eq $no_epoch
                    && $latest_entry->Source eq $entry->Source) {

                    $self->pointed_hint(
'latest-debian-changelog-entry-reuses-existing-version',
                        $latest_pointer,
                        $latest_version->literal,
                        $APPROXIMATELY_EQUAL,
                        $entry->Version,
                        '(last used: '. $entry->Date . ')'
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

            $self->pointed_hint(
                'changelog-file-missing-explicit-entry',$latest_pointer,
                $previous_version->literal, $ARROW,
                "$expected_previous (missing)", $ARROW,
                $latest_version->literal
              )
              unless $previous_version->literal eq $expected_previous
              || $latest_entry->Distribution eq 'bullseye'
              || $previous_entry->Distribution eq 'bullseye'
              || $latest_entry->Distribution =~ /-security$/i;

            if (   $latest_version->epoch eq $previous_version->epoch
                && $latest_version->upstream eq$previous_version->upstream
                && $latest_entry->Source eq $previous_entry->Source
                && !$processable->native) {

                $self->pointed_hint(
                    'possible-new-upstream-release-without-new-version',
                    $latest_pointer)
                  if $latest_entry->Changes
                  =~ /^\s*\*\s+new\s+upstream\s+(?:\S+\s+)?release\b/im;

                my $non_consecutive = 0;

                $non_consecutive = 1
                  if !length $latest_version->source_nmu
                  && $latest_version->maintainer_revision =~ /^\d+$/
                  && $previous_version->maintainer_revision =~ /^\d+$/
                  && $latest_version->maintainer_revision
                  != $previous_version->maintainer_revision + 1;

                $non_consecutive = 1
                  if $latest_version->maintainer_revision eq
                  $previous_version->maintainer_revision
                  && $latest_version->source_nmu =~ /^\d+$/
                  && $previous_version->source_nmu =~ /^\d+$/
                  && $latest_version->source_nmu
                  != $previous_version->source_nmu + 1;

                $non_consecutive = 1
                  if $latest_version->source_nmu =~ /^\d+$/
                  && !length $previous_version->source_nmu
                  && $latest_version->source_nmu != 1;

                $self->pointed_hint(
                    'non-consecutive-debian-revision',
                    $latest_pointer,$previous_version->literal,
                    $ARROW,$latest_version->literal
                )if $non_consecutive;
            }

            if ($latest_version->epoch ne $previous_version->epoch) {
                $self->pointed_hint(
                    'epoch-change-without-comment',$latest_pointer,
                    $previous_version->literal, $ARROW,
                    $latest_version->literal
                )unless $latest_entry->Changes =~ /\bepoch\b/im;

                $self->pointed_hint(
                    'epoch-changed-but-upstream-version-did-not-go-backwards',
                    $latest_pointer,$previous_version->literal,
                    $ARROW,$latest_version->literal
                  )
                  unless $processable->native
                  || versions_gt($previous_version->upstream,
                    $latest_version->upstream);
            }
        }
    }

    return;
}

# no copyright in udebs
sub binary {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;
    my $group = $self->group;

    my $is_symlink = 0;
    my $native_pkg;
    my $foreign_pkg;
    my @doc_files;

    # skip packages which have a /usr/share/doc/$pkg -> foo symlink
    my $docfile = $processable->installed->lookup("usr/share/doc/$pkg");
    return
      if defined $docfile && $docfile->is_symlink;

    # trailing slash in indicates a directory
    my $docdir = $processable->installed->lookup("usr/share/doc/$pkg/");
    @doc_files = grep { $_->is_file || $_->is_symlink } $docdir->children
      if defined $docdir;
    my @news_files
      = grep { $_->basename =~ m{\A NEWS\.Debian (?:\.gz)? \Z}ixsm }@doc_files;

    $self->pointed_hint('debian-news-file-not-compressed', $_->pointer)
      for grep { $_->basename !~ m{\.gz$} } @news_files;

    $self->pointed_hint('wrong-name-for-debian-news-file', $_->pointer)
      for grep { $_->basename =~ m{\.gz$} && $_->basename ne 'NEWS.Debian.gz' }
      @news_files;

    my @changelog_files = grep {
        $_->basename =~ m{\A changelog (?:\.html|\.Debian)? (?:\.gz)? \Z}xsm
    } @doc_files;

    # ubuntu permits symlinks; their profile suppresses the tag
    $self->pointed_hint('debian-changelog-file-is-a-symlink', $_->pointer)
      for grep { $_->is_symlink } @changelog_files;

    $self->pointed_hint('changelog-file-not-compressed', $_->pointer)
      for grep { $_->basename !~ m{ \.gz \Z}xsm } @changelog_files;

    # Check if changelog files are compressed with gzip -9.
    # It's a bit of an open question here what we should do
    # with a file named ChangeLog.  If there's also a
    # changelog file, it might be a duplicate, or the packager
    # may have installed NEWS as changelog intentionally.
    for my $item (@changelog_files) {

        next
          unless $item->basename =~ m{ \.gz \Z}xsm;

        my $resolved = $item->resolve_path;
        next
          unless defined $resolved;

        $self->pointed_hint('changelog-not-compressed-with-max-compression',
            $item->pointer)
          unless $resolved->file_type =~ /max compression/;
    }

    my @html_changelogs
      = grep { $_->basename =~ /^changelog\.html(?:\.gz)?$/ } @changelog_files;
    my @text_changelogs
      = grep { $_->basename =~ /^changelog(?:\.gz)?$/ } @changelog_files;

    if (!@text_changelogs) {

        $self->pointed_hint('html-changelog-without-text-version', $_->pointer)
          for @html_changelogs;
    }

    my $packagepath = 'usr/share/doc/' . $self->processable->name;
    my $news_item
      = $self->processable->installed->resolve_path(
        "$packagepath/NEWS.Debian.gz");

    my $news;
    if (defined $news_item && $news_item->is_file) {

        my $bytes = safe_qx('gunzip', '-c', $news_item->unpacked_path);

        # another check complains about invalid encoding
        if (valid_utf8($bytes)) {

            my $contents = decode_utf8($bytes);
            my $newslog = Lintian::Changelog->new;
            $newslog->parse($contents);

            for my $error (@{$newslog->errors}) {

                my $position = $error->[0];
                my $condition = $error->[1];

                my $pointer = $news_item->pointer($position);

                $self->pointed_hint('syntax-error-in-debian-news-file',
                    $pointer, $DOUBLE_QUOTE . $condition . $DOUBLE_QUOTE);
            }

            # Some checks on the most recent entry.
            if ($newslog->entries && defined @{$newslog->entries}[0]) {

                $news = @{$newslog->entries}[0];

                my $pointer = $news_item->pointer($news->position);

                $self->pointed_hint(
                    'debian-news-entry-has-strange-distribution',
                    $pointer,$news->Distribution)
                  if length $news->Distribution
                  && $news->Distribution eq 'UNRELEASED';

                check_spelling(
                    $self->data,
                    $news->Changes,
                    $group->spelling_exceptions,
                    $self->spelling_tag_emitter(
                        'spelling-error-in-news-debian', $news_item
                    ));

                $self->pointed_hint('debian-news-entry-uses-asterisk',$pointer)
                  if $news->Changes =~ /^ \s* [*] \s /x;
            }
        }
    }

    # is this a native Debian package?
    # If the version is missing, we assume it to be non-native
    # as it is the most likely case.
    my $source = $processable->fields->value('Source');
    my $source_version;
    if ($processable->fields->declares('Source') && $source =~ m/\((.*)\)/) {
        $source_version = $1;
    } else {
        $source_version = $processable->fields->value('Version');
    }
    if (defined $source_version) {
        $native_pkg = ($source_version !~ m/-/);
    } else {
        # We do not know, but assume it to non-native as it is
        # the most likely case.
        $native_pkg = 0;
    }
    $source_version = $processable->fields->value('Version') || '0-1';
    $foreign_pkg = (!$native_pkg && $source_version !~ m/-0\./);
    # A version of 1.2.3-0.1 could be either, so in that
    # case, both vars are false

    if ($native_pkg) {
        # native Debian package
        if (any { m/^changelog(?:\.gz)?$/} map { $_->basename } @doc_files) {
            # everything is fine
        } elsif (
            my $chg = first {
                $_->basename =~ m/^changelog[.]debian(?:\.gz)$/i;
            }
            @doc_files
        ) {
            $self->pointed_hint('wrong-name-for-changelog-of-native-package',
                $chg->pointer);

        } else {
            $self->hint(
                'no-changelog',
                "usr/share/doc/$pkg/changelog.gz",
                '(native package)'
            );
        }
    } else {
        # non-native (foreign :) Debian package

        # 1. check for upstream changelog
        my $found_upstream_text_changelog = 0;
        if (
            any { m/^changelog(\.html)?(?:\.gz)?$/ }
            map { $_->basename } @doc_files
        ) {
            $found_upstream_text_changelog = 1 unless $1;
            # everything is fine
        } else {
            # search for changelogs with wrong file name
            for my $item (@doc_files) {

                if (   $item->basename =~ m/^change/i
                    && $item->basename !~ m/debian/i) {

                    $self->pointed_hint('wrong-name-for-upstream-changelog',
                        $item->pointer);
                    last;
                }
            }
        }

        # 2. check for Debian changelog
        if (
            any { m/^changelog\.Debian(?:\.gz)?$/ }
            map { $_->basename } @doc_files
        ) {
            # everything is fine
        } elsif (
            my $chg = first {
                $_->basename =~ m/^changelog\.debian(?:\.gz)?$/i;
            }
            @doc_files
        ) {
            $self->pointed_hint('wrong-name-for-debian-changelog-file',
                $chg->pointer);

        } else {
            if ($foreign_pkg && $found_upstream_text_changelog) {
                $self->hint('debian-changelog-file-missing-or-wrong-name');

            } elsif ($foreign_pkg) {
                $self->hint(
                    'no-changelog',
                    "usr/share/doc/$pkg/changelog.Debian.gz",
                    '(non-native package)'
                );
            }
            # TODO: if uncertain whether foreign or native, either
            # changelog.gz or changelog.debian.gz should exists
            # though... but no tests catches this (extremely rare)
            # border case... Keep in mind this is only happening if we
            # have a -0.x version number... So not my priority to fix
            # --Jeroen
        }
    }

    my $changelog_item = $self->processable->changelog_item;
    return
      unless defined $changelog_item;

    # another check complains about invalid encoding
    my $changelog = $processable->changelog;

    for my $error (@{$changelog->errors}) {

        my $position = $error->[0];
        my $condition = $error->[1];

        my $pointer = $changelog_item->pointer($position);

        $self->pointed_hint('syntax-error-in-debian-changelog',
            $pointer, $DOUBLE_QUOTE . $condition . $DOUBLE_QUOTE);
    }

    # Check for some things in the raw changelog file and compute the
    # "offset" to the first line of the first entry.  We use this to
    # report the line number of "too-long" lines.  (#657402)
    my $real_start = $self->check_dch($changelog_item);

    my @entries = @{$changelog->entries};

    # all versions from the changelog
    my %allversions
      = map { $_ => 1 } grep { defined } map { $_->Version } @entries;

    # checks applying to all entries
    for my $entry (@entries) {

        my $position = $entry->position;
        my $version = $entry->Version;

        my $pointer = $changelog_item->pointer($position);

        if (length $entry->Maintainer) {
            my ($parsed) = Email::Address::XS->parse($entry->Maintainer);

            unless ($parsed->is_valid) {

                $self->pointed_hint(
                    'bogus-mail-host-in-debian-changelog',
                    $pointer,$entry->Maintainer,"(for version $version)",
                );
                next;
            }

            unless (
                all { length }
                ($parsed->address, $parsed->user, $parsed->host)
            ) {
                $self->pointed_hint(
                    'bogus-mail-host-in-debian-changelog',
                    $pointer,$parsed->format,"(for version $version)",
                );
                next;
            }

            $self->pointed_hint(
                'bogus-mail-host-in-debian-changelog',
                $pointer, $parsed->address,"(for version $version)",
              )
              unless is_domain($parsed->host,
                {domain_disable_tld_validation => 1});
        }
    }

    my $INVALID_DATES
      = $self->data->load('changelog-file/invalid-dates',qr/\s*=\>\s*/);

    if (@entries) {

        # checks related to the latest entry
        my $latest_entry = $entries[0];

        my $latest_pointer = $changelog_item->pointer($latest_entry->position);

        my $latest_timestamp = $latest_entry->Timestamp;

        if ($latest_timestamp) {

            my $warned = 0;
            my $longdate = $latest_entry->Date;

            for my $re ($INVALID_DATES->all()) {
                if ($longdate =~ m/($re)/i) {

                    my $match = $1;
                    my $repl = $INVALID_DATES->value($re);

                    $self->pointed_hint('invalid-date-in-debian-changelog',
                        $latest_pointer,"($match", $ARROW, "$repl)");

                    $warned = 1;
                }
            }

            my ($weekday_declared, $numberportion)
              = split(m/,\s*/, $longdate, 2);
            $numberportion //= $EMPTY;
            my ($tz, $weekday_actual);

            if ($numberportion =~ m/[ ]+ ([^ ]+)\Z/xsm) {
                $tz = $1;
                $weekday_actual = time2str('%a', $latest_timestamp, $tz);
            }

            if (not $warned and $tz and $weekday_declared ne $weekday_actual) {
                my $real_weekday = time2str('%A', $latest_timestamp, $tz);
                my $short_date = time2str('%Y-%m-%d', $latest_timestamp, $tz);
                $self->pointed_hint('debian-changelog-has-wrong-day-of-week',
                    $latest_pointer,"$short_date was a $real_weekday");
            }
        }

        # there is more than one changelog entry
        if (@entries > 1) {

            my $previous_entry = $entries[1];

            my $previous_timestamp = $previous_entry->Timestamp;

            $self->pointed_hint('latest-changelog-entry-without-new-date',
                $latest_pointer)
              if defined $latest_timestamp
              && defined $previous_timestamp
              && $latest_timestamp <= $previous_timestamp
              && $latest_entry->Distribution ne 'UNRELEASED';

            my $latest_dist = lc $latest_entry->Distribution;
            my $previous_dist = lc $previous_entry->Distribution;

            $self->pointed_hint('experimental-to-unstable-without-comment',
                $latest_pointer)
              if $latest_dist eq 'unstable'
              && $previous_dist eq 'experimental'
              && $latest_entry->Changes
              !~ m{ \b to \s+ ['"‘“]? (?:unstable|sid) ['"’”]? \b }im;

            my $changes = $group->changes;
            if ($changes) {
                my $changes_dist= lc $changes->fields->value('Distribution');

                my %codename;
                $codename{'unstable'} = 'sid';
                my @normalized
                  = uniq map { $codename{$_} // $_ }
                  ($latest_dist, $changes_dist);

                $self->pointed_hint(
                    'changelog-distribution-does-not-match-changes-file',
                    $latest_pointer,$latest_dist,
                    $NOT_EQUALS, $changes_dist
                )unless @normalized == 1;
            }

        }

        # Some checks should only be done against the most recent
        # changelog entry.
        my $changes = $latest_entry->Changes || $EMPTY;

        if (@entries == 1) {

            if ($latest_entry->Version && $latest_entry->Version =~ /-1$/) {
                $self->pointed_hint('initial-upload-closes-no-bugs',
                    $latest_pointer)
                  unless @{ $latest_entry->Closes };

                $self->pointed_hint(
                    'new-package-uses-date-based-version-number',
                    $latest_pointer,
                    $latest_entry->Version,
                    '(better: 0~' . $latest_entry->Version .')'
                )if $latest_entry->Version =~ m/^\d{8}/;
            }

            $self->pointed_hint('changelog-is-dh_make-template',
                $latest_pointer)
              if $changes
              =~ /(?:#?\s*)(?:\d|n)+ is the bug number of your ITP/i;
        }

        while ($changes =~ /(closes[\s;]*(?:bug)?\#?\s?\d{6,})[^\w]/ig) {

            my $closes = $1;

            $self->pointed_hint('possible-missing-colon-in-closes',
                $latest_pointer, $closes)
              if length $closes;
        }

        if ($changes =~ m/(TEMP-\d{7}-[0-9a-fA-F]{6})/) {

            my $temporary_cve = $1;

            $self->pointed_hint(
                'changelog-references-temp-security-identifier',
                $latest_pointer, $temporary_cve);
        }

        # check for bad intended distribution
        if (
            $changes =~ m{uploads? \s+ to \s+
                            (?'intended'testing|unstable|experimental|sid)}xi
        ){
            my $intended = lc($+{intended});

            $intended = 'unstable'
              if $intended eq 'sid';

            my $uploaded = $latest_entry->Distribution;

            $self->pointed_hint('bad-intended-distribution', $latest_pointer,
                "intended for $intended but uploaded to $uploaded")
              if $uploaded ne $intended
              && $uploaded ne 'UNRELEASED';
        }

        if ($changes =~ m{ (Close: \s+ [#] \d+) }xi) {

            my $statement = $1;

            $self->pointed_hint('misspelled-closes-bug', $latest_pointer,
                $statement);
        }

        my $changesempty = $changes;
        $changesempty =~ s/\W//gms;

        $self->pointed_hint('changelog-empty-entry', $latest_pointer)
          if !length $changesempty
          && $latest_entry->Distribution ne 'UNRELEASED';

        # before bug 50004 bts removed bug instead of archiving
        for my $bug (@{$latest_entry->Closes}) {

            $self->pointed_hint('improbable-bug-number-in-closes',
                $latest_pointer, $bug)
              if $bug < $FIRST_ARCHIVED_BUG_NUMBER
              || $bug >= $OUT_OF_REACH_BUG_NUMBER;
        }

        # Compare against NEWS.Debian if available.
        for my $field (qw/Distribution Urgency/) {

            $self->pointed_hint(
                'changelog-news-debian-mismatch',
                $news_item->pointer($news->position),
                $field,
                $latest_entry->$field,
                $NOT_EQUALS,
                $news->$field
              )
              if defined $news
              && length $news->Version
              && $news->Version eq $latest_entry->Version
              && $news->$field ne $latest_entry->$field;
        }

        $self->pointed_hint(
            'debian-news-entry-has-unknown-version',
            $news_item->pointer($news->position),
            $news->Version
          )
          if defined $news
          && length $news->Version
          && !exists $allversions{$news->Version};

        # Parse::DebianChangelog adds an additional space to the
        # beginning of each line, so we have to adjust for that in the
        # length check.
        my @lines = split(/\n/, $changes);

        # real start
        my $position = $real_start;
        for my $line (@lines) {

            my $pointer = $changelog_item->pointer($position);

            if ($line =~ /^   [*]\s(.{1,5})$/) {

                my $excerpt = $1;

                $self->pointed_hint('debian-changelog-line-too-short',
                    $pointer, $excerpt)
                  unless $1 =~ /:$/;
            }

            $self->pointed_hint('debian-changelog-line-too-long', $pointer)
              if length $line >= $MAXIMUM_WIDTH
              && $line !~ /^ [\s.o*+-]* (?: [Ss]ee:?\s+ )? \S+ $/msx;

        } continue {
            ++$position;
        }

        # Strip out all lines that contain the word spelling to avoid false
        # positives on changelog entries for spelling fixes.
        $changes =~ s/^.*(?:spelling|typo).*\n//gm;

        check_spelling(
            $self->data,
            $changes,
            $group->spelling_exceptions,
            $self->spelling_tag_emitter(
                'spelling-error-in-changelog', $changelog_item
            ));
    }

    return;
}

# read the changelog itself and check for some issues we cannot find
# with Parse::DebianChangelog.  Also return the "real" line number for
# the first line of text in the first entry.
#
sub check_dch {
    my ($self) = @_;

    my $unresolved = $self->processable->changelog_item;

    # stop for dangling symbolic link
    my $item = $unresolved->resolve_path;
    return 0
      unless defined $item;

    # return empty changelog
    return 0
      unless $item->is_file && $item->is_open_ok;

    # emacs only looks at the last "local variables" in a file, and only at
    # one within 3000 chars of EOF and on the last page (^L), but that's a bit
    # pesky to replicate.  Demanding a match of $prefix and $suffix ought to
    # be enough to avoid false positives.

    my $contents;
    if ($item->basename =~ m{ [.]gz $}x) {

        my $bytes = safe_qx('gunzip', '-c', $item->unpacked_path);

        return 0
          unless valid_utf8($bytes);

        $contents = decode_utf8($bytes);

    } else {

        # empty unless valis UTF-8
        $contents = $item->decoded_utf8;
    }

    my @lines = split(m{\n}, $contents);

    my $prefix;
    my $suffix;
    my $real_start = 0;

    my $saw_tab_lead = 0;

    my $position = 1;
    for my $line (@lines) {

        ++$real_start
          unless $saw_tab_lead;

        $saw_tab_lead = 1
          if $line =~ /^\s+\S/;

        my $pointer = $item->pointer($position);

        if (
            $line
            =~ m{ closes: \s* (( (?:bug)? [#]? \s? \d*) [[:alpha:]] \w*) }ix
            || $line =~ m{ closes: \s* (?:bug)? [#]? \s? \d+
              (?: , \s* (?:bug)? [#]? \s? \d+ )*
              (?: , \s* (( (?:bug)? [#]? \s? \d* ) [[:alpha:]] \w*)) }ix
        ) {

            my $bug = $1;

            $self->pointed_hint('wrong-bug-number-in-closes', $pointer, $bug)
              if length $2;
        }

        if ($line =~ /^(.*)Local\ variables:(.*)$/i) {
            $prefix = $1;
            $suffix = $2;
        }

        # emacs allows whitespace between prefix and variable, hence \s*
        $self->pointed_hint(
            'debian-changelog-file-contains-obsolete-user-emacs-settings',
            $pointer)
          if defined $prefix
          && defined $suffix
          && $line =~ /^\Q$prefix\E\s*add-log-mailing-address:.*\Q$suffix\E$/;

    } continue {
        ++$position;
    }

    return $real_start;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

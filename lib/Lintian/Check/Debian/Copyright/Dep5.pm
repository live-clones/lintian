# debian/copyright/dep5 -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2011 Jakub Wilk
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

package Lintian::Check::Debian::Copyright::Dep5;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any all none uniq);
use Syntax::Keyword::Try;
use Text::Glob qw(match_glob);
use Time::Piece;
use XML::LibXML;

use Lintian::Deb822::File;
use Lintian::Pointer::Item;
use Lintian::Relation::Version qw(versions_compare);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LAST_SIGNIFICANT_DEP5_CHANGE => '0+svn~166';
const my $LAST_DEP5_OVERHAUL => '0+svn~148';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $COLON => q{:};
const my $HYPHEN => q{-};
const my $ASTERISK => q{*};

const my $MINIMUM_CREATIVE_COMMMONS_LENGTH => 20;
const my $LAST_ITEM => -1;

const my %NEW_FIELD_NAMES        => (
    'Format-Specification' => 'Format',
    'Maintainer'           => 'Upstream-Contact',
    'Upstream-Maintainer'  => 'Upstream-Contact',
    'Contact'              => 'Upstream-Contact',
    'Name'                 => 'Upstream-Name',
);

sub source {
    my ($self) = @_;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless defined $debian_dir;

    my @installables = $self->processable->debian_control->installables;
    my @additional = map { $_ . '.copyright' } @installables;

    my @candidates = ('copyright', @additional);
    my @files = grep { defined $_ && !$_->is_symlink }
      map { $debian_dir->child($_) } @candidates;

    # another check complains about legacy encoding, if needed
    my @valid_utf8 = grep { $_->is_valid_utf8 } @files;

    $self->check_dep5_copyright($_) for @valid_utf8;

    return;
}

# The policy states, since 4.0.0, that people should use "https://" for the
# format URI. This is checked later in check_dep5_copyright.
# return undef is not dep5 and '' if unknown version
sub find_dep5_version {
    my ($self, $file, $original_uri) = @_;

    my $uri = $original_uri;
    my $version;

    my $pointer = Lintian::Pointer::Item->new;
    $pointer->item($file);

    if ($uri =~ /\b(?:rev=REVISION|VERSIONED_FORMAT_URL)\b/) {

        $self->pointed_hint('boilerplate-copyright-format-uri', $pointer,$uri);
        return undef;
    }

    if (
        $uri =~ s{ https?://wiki\.debian\.org/
                                Proposals/CopyrightFormat\b}{}xsm
    ){
        $version = '0~wiki';

        $version = "$version~$1"
          if $uri =~ /^\?action=recall&rev=(\d+)$/;

        return $version;
    }

    if ($uri =~ m{^https?://dep(-team\.pages)?\.debian\.net/deps/dep5/?$}) {

        $version = '0+svn';
        return $version;
    }

    if (
        $uri =~ s{\A https?://svn\.debian\.org/
                                  wsvn/dep/web/deps/dep5\.mdwn\b}{}xsm
    ){
        $version = '0+svn';

        $version = "$version~$1"
          if $uri =~ /^\?(?:\S+[&;])?rev=(\d+)(?:[&;]\S+)?$/;

        return $version;
    }
    if (
        $uri =~ s{ \A https?://(?:svn|anonscm)\.debian\.org/
                                    viewvc/dep/web/deps/dep5\.mdwn\b}{}xsm
    ){
        $version = '0+svn';
        $uri =~ m{\A \? (?:\S+[&;])?
                             (?:pathrev|revision|rev)=(\d+)(?:[&;]\S+)?
                          \Z}xsm
          and $version = "$version~$1";
        return $version;
    }
    if (
        $uri =~ m{ \A
                       https?://www\.debian\.org/doc/
                       (?:packaging-manuals/)?copyright-format/(\d+\.\d+)/?
                   \Z}xsm
    ){
        $version = $1;
        return $version;
    }

    $self->pointed_hint('unknown-copyright-format-uri',
        $pointer, $original_uri);

    return undef;
}

sub check_dep5_copyright {
    my ($self, $copyright_file) = @_;

    my $rough_pointer = Lintian::Pointer::Item->new;
    $rough_pointer->item($copyright_file);

    my $contents = $copyright_file->decoded_utf8;

    if ($contents =~ /^Files-Excluded:/m) {

        if ($contents
            =~ m{^Format:.*/doc/packaging-manuals/copyright-format/1.0/?$}m) {

            $self->pointed_hint('repackaged-source-not-advertised',
                $rough_pointer)
              unless $self->processable->repacked
              || $self->processable->native;

        } else {
            $self->pointed_hint('files-excluded-without-copyright-format-1.0',
                $rough_pointer);
        }
    }

    unless (
        $contents =~ m{
               (?:^ | \n)
               (?i: format(?: [:] |[-\s]spec) )
               (?: . | \n\s+ )*
               (?: /dep[5s]?\b | \bDEP ?5\b
                 | [Mm]achine-readable\s(?:license|copyright)
                 | /copyright-format/ | CopyrightFormat
                 | VERSIONED_FORMAT_URL
               ) }x
    ){

        $self->pointed_hint('no-dep5-copyright', $rough_pointer);
        return;
    }

    # get format before parsing as a debian control file
    my $first_para = $contents;
    $first_para =~ s/^#.*//mg;
    $first_para =~ s/[ \t]+$//mg;
    $first_para =~ s/^\n+//g;
    $first_para =~ s/\n\n.*/\n/s;    #;; hi emacs
    $first_para =~ s/\n?[ \t]+/ /g;

    if ($first_para !~ /^Format(?:-Specification)?:\s*(\S+)\s*$/mi) {
        $self->pointed_hint('unknown-copyright-format-uri', $rough_pointer);
        return;
    }

    my $uri = $1;

    # strip fragment identifier
    $uri =~ s/^([^#\s]+)#/$1/;

    my $version = $self->find_dep5_version($copyright_file, $uri);
    return
      unless defined $version;

    if ($version =~ /wiki/) {
        $self->pointed_hint('wiki-copyright-format-uri', $rough_pointer, $uri);

    } elsif ($version =~ /svn$/) {
        $self->pointed_hint('unversioned-copyright-format-uri',
            $rough_pointer, $uri);

    } elsif (versions_compare($version, '<<', $LAST_SIGNIFICANT_DEP5_CHANGE)) {
        $self->pointed_hint('out-of-date-copyright-format-uri',
            $rough_pointer, $uri);

    } elsif ($uri =~ m{^http://www\.debian\.org/}) {
        $self->pointed_hint('insecure-copyright-format-uri',
            $rough_pointer, $uri);
    }

    return
      if versions_compare($version, '<<', $LAST_DEP5_OVERHAUL);

    # probably DEP 5 format; let's try more checks
    my $deb822 = Lintian::Deb822::File->new;

    my @sections;
    try {
        @sections = $deb822->read_file($copyright_file->unpacked_path);

    } catch {
        my $error = $@;
        chomp $error;
        $error =~ s{^syntax error in }{};

        $self->pointed_hint('syntax-error-in-dep5-copyright',
            $rough_pointer, $@);

        return;
    }

    return
      unless @sections;

    my %found_standalone;
    my %license_names_by_section;
    my %license_text_by_section;
    my %license_identifier_by_section;

    my @license_sections = grep { $_->declares('License') } @sections;
    for my $section (@license_sections) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($section->position('License'));

        $self->pointed_hint('tab-in-license-text', $pointer)
          if $section->untrimmed_value('License') =~ /\t/;

        my ($anycase_identifier, $license_text)
          = split(/\n/, $section->untrimmed_value('License'), 2);

        $anycase_identifier //= $EMPTY;
        $license_text //= $EMPTY;

        # replace some weird characters
        $anycase_identifier =~ s/[(),]/ /g;

        # trim both ends
        $anycase_identifier =~ s/^\s+|\s+$//g;
        $license_text =~ s/^\s+|\s+$//g;

        my $license_identifier = lc $anycase_identifier;

        my @license_names
          = grep { length } split(/\s+(?:and|or)\s+/, $license_identifier);

        $license_names_by_section{$section->position} = \@license_names;
        $license_text_by_section{$section->position} = $license_text;
        $license_identifier_by_section{$section->position}
          = $license_identifier;

        $self->pointed_hint('empty-short-license-in-dep5-copyright', $pointer)
          unless length $license_identifier;

        $self->pointed_hint('pipe-symbol-used-as-license-disjunction',
            $pointer, $license_identifier)
          if $license_identifier =~ m{\s+\|\s+};

        for my $name (@license_names) {
            if ($name =~ /\s/) {

                if($name =~ /[^ ]+ \s+ with \s+ (.*)/x) {

                    my $exceptiontext = $1;

                    $self->pointed_hint(
                        'bad-exception-format-in-dep5-copyright',
                        $pointer, $name)
                      unless $exceptiontext =~ /[^ ]+ \s+ exception/x;

                } else {

                    $self->pointed_hint(
                        'space-in-std-shortname-in-dep5-copyright',
                        $pointer, $name);
                }
            }

            $self->pointed_hint('invalid-short-name-in-dep5-copyright',
                $pointer, $name)
              if $name =~ m{^(?:agpl|gpl|lgpl)[^-]?\d(?:\.\d)?\+?$}
              || $name =~ m{^bsd(?:[^-]?[234][^-]?(?:clause|cluase))?$};

            $self->pointed_hint('license-problem-undefined-license',
                $pointer, $name)
              if $name eq $HYPHEN
              || $name
              =~ m{\b(?:fixmes?|todos?|undefined?|unknown?|unspecified)\b};
        }

        # stand-alone license
        if (   length $license_identifier
            && length $license_text
            && !$section->declares('Files')) {

            $found_standalone{$license_identifier} //= [];
            push(@{$found_standalone{$license_identifier}}, $section);
        }

        if ($license_identifier =~ /^cc-/ && length $license_text) {

            my $num_lines = $license_text =~ tr/\n//;

            $self->pointed_hint('incomplete-creative-commons-license',
                $pointer, $license_identifier)
              if $num_lines < $MINIMUM_CREATIVE_COMMMONS_LENGTH;
        }
    }

    my @not_unique
      = grep { @{$found_standalone{$_}} > 1 } keys %found_standalone;
    for my $name (@not_unique) {

        next
          if $name eq 'public-domain';

        for my $section (@{$found_standalone{$name}}) {

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($copyright_file);
            $pointer->position($section->position('License'));

            $self->pointed_hint('dep5-copyright-license-name-not-unique',
                $pointer, $name);
        }
    }

    my ($header, @followers) = @sections;

    my @obsolete_fields = grep { $header->declares($_) } keys %NEW_FIELD_NAMES;
    for my $old_name (@obsolete_fields) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($header->position($old_name));

        $self->pointed_hint('obsolete-field-in-dep5-copyright',
            $pointer, $old_name, $NEW_FIELD_NAMES{$old_name});
    }

    my $header_pointer = Lintian::Pointer::Item->new;
    $header_pointer->item($copyright_file);
    $header_pointer->position($header->position);

    $self->pointed_hint('missing-field-in-dep5-copyright',
        $header_pointer, 'Format')
      if none { $header->declares($_) } qw(Format Format-Specification);

    my $debian_control = $self->processable->debian_control;

    $self->pointed_hint('missing-explanation-for-contrib-or-non-free-package',
        $header_pointer)
      if $debian_control->source_fields->value('Section')
      =~ m{^(?:contrib|non-free)(?:/.+)?$}
      && (none { $header->declares($_) } qw{Comment Disclaimer});

    $self->pointed_hint('missing-explanation-for-repacked-upstream-tarball',
        $header_pointer)
      if $self->processable->repacked
      && $header->value('Source') =~ m{^https?://}
      && (none { $header->declares($_) } qw{Comment Files-Excluded});

    my @ambiguous_sections = grep {
             $_->declares('License')
          && $_->declares('Copyright')
          && !$_->declares('Files')
    } @followers;

    for my $section (@ambiguous_sections) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($section->position);

        $self->pointed_hint('ambiguous-paragraph-in-dep5-copyright',$pointer);
    }

    my @unknown_sections
      = grep {!$_->declares('License')&& !$_->declares('Files')} @followers;

    for my $section (@unknown_sections) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($section->position);

        $self->pointed_hint('unknown-paragraph-in-dep5-copyright',$pointer);
    }

    my @shipped_items;

    if ($self->processable->native) {
        @shipped_items = @{$self->processable->patched->sorted_list};

    } else {
        @shipped_items = @{$self->processable->orig->sorted_list};

        # remove ./debian folder from orig, if any
        @shipped_items = grep { !m{^debian/} } @shipped_items
          if $self->processable->fields->value('Format') eq '3.0 (quilt)';

        # add ./ debian folder from patched
        my $debian_dir = $self->processable->patched->resolve_path('debian/');
        push(@shipped_items, $debian_dir->descendants)
          if $debian_dir;
    }

    my @shipped_names
      = sort map { $_->name } grep { $_->is_file } @shipped_items;

    my @excluded;
    for my $wildcard ($header->trimmed_list('Files-Excluded')) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($header->position('Files-Excluded'));

        my @offenders = escape_errors($wildcard);

        $self->pointed_hint('invalid-escape-sequence-in-dep5-copyright',
            $pointer, '(Files-Excluded)', $_)
          for @offenders;

        next
          if @offenders;

        # also match dir/filename for Files-Excluded: dir
        unless ($wildcard =~ /\*/ || $wildcard =~ /\?/) {

            my $candidate = $wildcard;
            $candidate .= $SLASH
              unless $candidate =~ m{/$};

            my $item = $self->processable->orig->lookup($candidate);

            $wildcard = $candidate . $ASTERISK
              if defined $item && $item->is_dir;
        }

        local $Text::Glob::strict_leading_dot = 0;
        local $Text::Glob::strict_wildcard_slash = 0;

        # disable Text::Glob character classes and alternations
        my $dulled = $wildcard;
        $dulled =~ s/([{}\[\]])/\\$1/g;

        my @match = match_glob($dulled, @shipped_names);

        # do not flag missing matches; uscan already excluded them
        push(@excluded, @match);
    }

    my @included;
    for my $wildcard ($header->trimmed_list('Files-Included')) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($header->position('Files-Included'));

        my @offenders = escape_errors($wildcard);

        $self->pointed_hint('invalid-escape-sequence-in-dep5-copyright',
            $pointer, '(Files-Included)', $_)
          for @offenders;

        next
          if @offenders;

        # also match dir/filename for Files-Excluded: dir
        unless ($wildcard =~ /\*/ || $wildcard =~ /\?/) {

            my $candidate = $wildcard;
            $candidate .= $SLASH
              unless $candidate =~ m{/$};

            my $item = $self->processable->orig->lookup($candidate);

            $wildcard = $candidate . $ASTERISK
              if defined $item && $item->is_dir;
        }

        local $Text::Glob::strict_leading_dot = 0;
        local $Text::Glob::strict_wildcard_slash = 0;

        # disable Text::Glob character classes and alternations
        my $dulled = $wildcard;
        $dulled =~ s/([{}\[\]])/\\$1/g;

        my @match = match_glob($dulled, @shipped_names);

        $self->pointed_hint(
            'superfluous-file-pattern', $pointer,
            '(Files-Included)', $wildcard
        )unless @match;

        push(@included, @match);
    }

    my $lc = List::Compare->new(\@included, \@excluded);
    my @affirmed = $lc->get_Lonly;
    my @unwanted = $lc->get_Ronly;

    # already unique
    for my $name (@affirmed) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($header->position('Files-Included'));

        $self->pointed_hint('file-included-already', $pointer, $name);
    }

    # already unique
    for my $name (@unwanted) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($header->position('Files-Excluded'));

        $self->pointed_hint('source-ships-excluded-file',$pointer, $name)
          unless $name =~ m{^(?:debian|\.pc)/};
    }

    my @notice_names= grep { m{(^|/)(COPYING[^/]*|LICENSE)$} } @shipped_names;
    my @quilt_names = grep { m{^\.pc/} } @shipped_names;

    my @names_with_comma = grep { /,/ } @shipped_names;
    my @fields_with_comma = grep { $_->value('Files') =~ /,/ } @followers;

    for my $section (@fields_with_comma) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($section->position('Files'));

        $self->pointed_hint('comma-separated-files-in-dep5-copyright',$pointer)
          if !@names_with_comma;
    }

    # only attempt to evaluate globbing if commas could be legal
    my $check_wildcards = !@fields_with_comma || @names_with_comma;

    my @files_sections = grep {$_->declares('Files')} @followers;

    for my $section (@files_sections) {

        if (!length $section->value('Files')) {

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($copyright_file);
            $pointer->position($section->position('Files'));

            $self->pointed_hint('missing-field-in-dep5-copyright',
                $pointer,'(empty field)', 'Files');
        }

        my $section_pointer = Lintian::Pointer::Item->new;
        $section_pointer->item($copyright_file);
        $section_pointer->position($section->position);

        $self->pointed_hint('missing-field-in-dep5-copyright',
            $section_pointer, 'License')
          if !$section->declares('License');

        $self->pointed_hint('missing-field-in-dep5-copyright',
            $section_pointer, 'Copyright')
          if !$section->declares('Copyright');

        if ($section->declares('Copyright')
            && !length $section->value('Copyright')) {

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($copyright_file);
            $pointer->position($section->position('Copyright'));

            $self->pointed_hint('missing-field-in-dep5-copyright',
                $pointer, '(empty field)', 'Copyright');
        }
    }

    my %sections_by_wildcard;
    my %wildcard_by_file;
    my %required_standalone;
    my @redundant_wildcards;

    my $section_count = 0;
    for my $section (@followers) {

        my $wildcard_pointer = Lintian::Pointer::Item->new;
        $wildcard_pointer->item($copyright_file);
        $wildcard_pointer->position($section->position('Files'));

        my $copyright_pointer = Lintian::Pointer::Item->new;
        $copyright_pointer->item($copyright_file);
        $copyright_pointer->position($section->position('Copyright'));

        my $license_pointer = Lintian::Pointer::Item->new;
        $license_pointer->item($copyright_file);
        $license_pointer->position($section->position('License'));

        my @license_names
          = @{$license_names_by_section{$section->position} // []};
        my $license_text = $license_text_by_section{$section->position};

        if ($section->declares('Files') && !length $license_text) {
            $required_standalone{$_} = $section for @license_names;
        }

        my @wildcards;

        # If it is the first paragraph, it might be an instance of
        # the (no-longer) optional "first Files-field".
        if (   $section_count == 0
            && $section->declares('License')
            && $section->declares('Copyright')
            && !$section->declares('Files')) {

            @wildcards = ($ASTERISK);

        } else {
            @wildcards = $section->trimmed_list('Files');
        }

        my @rightholders = $section->trimmed_list('Copyright', qr{ \n }x);
        my @years = map { /(\d{4})/g } @rightholders;
        my @changelog_entries = @{$self->processable->changelog->entries};

        if (   @years
            && @changelog_entries
            && (any { m{^ debian (?: / | $) }x } @wildcards)) {

            my @descending = reverse sort { $a <=> $b } @years;
            my $latest_copyright = $descending[0];

            my $tp = Time::Piece->strptime($changelog_entries[0]->Date,
                '%a, %d %b %Y %T %z');
            my $latest_changelog = $tp->year;

            $self->pointed_hint('update-debian-copyright', $copyright_pointer,
                $latest_copyright, 'vs', $tp->year)
              if $latest_copyright < $tp->year;
        }

        for my $wildcard (@wildcards) {
            $sections_by_wildcard{$wildcard} //= [];
            push(@{$sections_by_wildcard{$wildcard}}, $section);
        }

        $self->pointed_hint(
            'global-files-wildcard-not-first-paragraph-in-dep5-copyright',
            $wildcard_pointer)
          if (any { $_ eq $ASTERISK } @wildcards) && $section_count > 0;

        # stand-alone license paragraph
        $self->pointed_hint('missing-license-text-in-dep5-copyright',
            $license_pointer, $section->untrimmed_value('License'))
          if !@wildcards
          && $section->declares('License')
          && !length $license_text;

        next
          unless $check_wildcards;

        my %wildcards_same_section_by_file;

        for my $wildcard (@wildcards) {

            my @offenders = escape_errors($wildcard);

            $self->pointed_hint('invalid-escape-sequence-in-dep5-copyright',
                $wildcard_pointer, $_)
              for @offenders;

            next
              if @offenders;

            local $Text::Glob::strict_leading_dot = 0;
            local $Text::Glob::strict_wildcard_slash = 0;

            # disable Text::Glob character classes and alternations
            my $dulled = $wildcard;
            $dulled =~ s/([{}\[\]])/\\$1/g;

            my @covered = match_glob($dulled, @shipped_names);

            for my $name (@covered) {
                $wildcards_same_section_by_file{$name} //= [];
                push(@{$wildcards_same_section_by_file{$name}}, $wildcard);
            }
        }

        my @overwritten = grep { length $wildcard_by_file{$_} }
          keys %wildcards_same_section_by_file;

        for my $name (@overwritten) {

            my $winning_wildcard
              = @{$wildcards_same_section_by_file{$name}}[$LAST_ITEM];
            my $loosing_wildcard = $wildcard_by_file{$name};

            my $winner_depth = ($winning_wildcard =~ tr{/}{});
            my $looser_depth = ($loosing_wildcard =~ tr{/}{});

            $self->pointed_hint('globbing-patterns-out-of-order',
                $wildcard_pointer,$loosing_wildcard, $winning_wildcard, $name)
              if $looser_depth > $winner_depth;
        }

        # later matches have precendence; depends on section ordering
        $wildcard_by_file{$_}
          = @{$wildcards_same_section_by_file{$_}}[$LAST_ITEM]
          for keys %wildcards_same_section_by_file;

        my @overmatched_same_section
          = grep { @{$wildcards_same_section_by_file{$_}} > 1 }
          keys %wildcards_same_section_by_file;

        for my $file (@overmatched_same_section) {

            my $patterns
              = join($SPACE, sort @{$wildcards_same_section_by_file{$file}});

            $self->pointed_hint('redundant-globbing-patterns',
                $wildcard_pointer,"($patterns) for $file");
        }

        push(@redundant_wildcards,
            map { @{$wildcards_same_section_by_file{$_}} }
              @overmatched_same_section);

    } continue {
        $section_count++;
    }

    if ($check_wildcards) {

        my @duplicate_wildcards= grep { @{$sections_by_wildcard{$_}} > 1 }
          keys %sections_by_wildcard;

        for my $wildcard (@duplicate_wildcards) {

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($copyright_file);

            my $lines = join($SPACE,
                map { $_->position('Files') }
                  @{$sections_by_wildcard{$wildcard}});

            $self->pointed_hint('duplicate-globbing-patterns', $pointer,
                $wildcard, '(lines $lines)');
        }

        # do not issue next tag for duplicates or redundant wildcards
        my $wildcard_lc = List::Compare->new(
            [keys %sections_by_wildcard],
            [(
                    values %wildcard_by_file, @duplicate_wildcards,
                    @redundant_wildcards
                )]);
        my @matches_nothing = $wildcard_lc->get_Lonly;

        for my $wildcard (@matches_nothing) {
            for my $section (@{$sections_by_wildcard{$wildcard}}) {

                my $pointer = Lintian::Pointer::Item->new;
                $pointer->item($copyright_file);
                $pointer->position($section->position('Files'));

                $self->pointed_hint('superfluous-file-pattern', $pointer,
                    $wildcard);
            }
        }

        my %sections_by_file;
        for my $name (keys %wildcard_by_file) {

            $sections_by_file{$name} //= [];
            my $wildcard = $wildcard_by_file{$name};

            push(
                @{$sections_by_file{$name}},
                @{$sections_by_wildcard{$wildcard}});
        }

        my %license_identifiers_by_file;
        for my $name (keys %sections_by_file) {

            $license_identifiers_by_file{$name} //= [];

            push(
                @{$license_identifiers_by_file{$name}},
                $license_identifier_by_section{$_->position}
            ) for @{$sections_by_file{$name}};
        }

        my @xml_searchspace = keys %license_identifiers_by_file;

        # do not examine Lintian's test suite for appstream metadata
        @xml_searchspace = grep { !m{t/} } @xml_searchspace
          if $self->processable->name eq 'lintian';

        for my $name (@xml_searchspace) {

            next
              if $name =~ '^\.pc/';

            next
              unless $name =~ /\.xml$/;

            my $parser = XML::LibXML->new;
            $parser->set_option('no_network', 1);

            my $file = $self->processable->patched->resolve_path($name);
            my $doc;
            try {
                $doc = $parser->parse_file($file->unpacked_path);

            } catch {
                next;
            }

            next
              unless $doc;

            my @nodes = $doc->findnodes('/component/metadata_license');
            next
              unless @nodes;

            # take first one
            my $first = $nodes[0];
            next
              unless $first;

            my $seen = lc($first->firstChild->data // $EMPTY);
            next
              unless $seen;

            my @wanted = @{$license_identifiers_by_file{$name}};
            my @mismatched = grep { $_ ne $seen } @wanted;

            $self->pointed_hint('inconsistent-appstream-metadata-license',
                $rough_pointer, $name, "($seen != $_)")
              for @mismatched;
        }

        my @no_license_needed = (@quilt_names, @notice_names);
        my $unlicensed_lc
          = List::Compare->new(\@shipped_names, \@no_license_needed);
        my @license_needed = $unlicensed_lc->get_Lonly;

        my @not_covered
          = grep { !@{$sections_by_file{$_} // []} } @license_needed;

        $self->pointed_hint('file-without-copyright-information',
            $rough_pointer, $_)
          for @not_covered;
    }

    my $standalone_lc= List::Compare->new([keys %required_standalone],
        [keys %found_standalone]);
    my @missing_standalone = $standalone_lc->get_Lonly;
    my @matched_standalone = $standalone_lc->get_intersection;
    my @unused_standalone = $standalone_lc->get_Ronly;

    for my $license (@missing_standalone) {

        my $section = $required_standalone{$license};

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($section->position('License'));

        $self->pointed_hint('missing-license-paragraph-in-dep5-copyright',
            $pointer, $license);
    }

    for my $license (grep { $_ ne 'public-domain' } @unused_standalone) {

        for my $section (@{$found_standalone{$license}}) {

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($copyright_file);
            $pointer->position($section->position('License'));

            $self->pointed_hint('unused-license-paragraph-in-dep5-copyright',
                $pointer, $license);
        }
    }

    for my $license (@matched_standalone) {

        my $section = $required_standalone{$license};

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($copyright_file);
        $pointer->position($section->position('Files'));

        $self->pointed_hint('dep5-file-paragraph-references-header-paragraph',
            $pointer, $license)
          if all { $_ == $header } @{$found_standalone{$license}};
    }

    # license files do not require their own entries in d/copyright.
    my $license_lc
      = List::Compare->new(\@notice_names, [keys %sections_by_wildcard]);
    my @listed_licenses = $license_lc->get_intersection;

    $self->pointed_hint('license-file-listed-in-debian-copyright',
        $rough_pointer, $_)
      for @listed_licenses;

    return;
}

sub escape_errors {
    my ($escaped) = @_;

    my @sequences = ($escaped =~ m{\\.?}g);
    my @illegal = grep { !m{^\\[*?]$} } @sequences;

    return @illegal;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

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

package Lintian::debian::copyright::dep5;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use List::MoreUtils qw(any all none uniq);
use Text::Glob qw(match_glob);
use XML::LibXML;

use Lintian::Deb822::File;
use Lintian::Relation::Version qw(versions_compare);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};
use constant COLON => q{:};
use constant ASTERISK => q{*};
use constant LEFT_SQUARE => q{[};
use constant RIGHT_SQUARE => q{]};

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $LAST_SIGNIFICANT_DEP5_CHANGE = '0+svn~166';
my $LAST_DEP5_OVERHAUL = '0+svn~148';

my %NEW_FIELD_NAMES        = (
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
    my @files = grep { defined } map { $debian_dir->child($_) } @candidates;

    # another check complains about legacy encoding, if needed
    my @valid_utf8 = grep { $_->is_valid_utf8 } @files;

    $self->check_dep5_copyright($_) for @valid_utf8;

    return;
}

# The policy states, since 4.0.0, that people should use "https://" for the
# format URI. This is checked later in check_dep5_copyright.
# return undef is not dep5 and '' if unknown version
sub find_dep5_version {
    my ($self, $original_uri) = @_;

    my $uri = $original_uri;
    my $version;

    if ($uri =~ m,\b(?:rev=REVISION|VERSIONED_FORMAT_URL)\b,) {
        $self->hint('boilerplate-copyright-format-uri', $uri);
        return;
    }

    if (
        $uri =~ s{ https?://wiki\.debian\.org/
                                Proposals/CopyrightFormat\b}{}xsm
    ){
        $version = '0~wiki';
        $uri =~ m,^\?action=recall&rev=(\d+)$,
          and $version = "$version~$1";
        return $version;
    }
    if ($uri =~ m,^https?://dep(-team\.pages)?\.debian\.net/deps/dep5/?$,) {
        $version = '0+svn';
        return $version;
    }
    if (
        $uri =~ s{\A https?://svn\.debian\.org/
                                  wsvn/dep/web/deps/dep5\.mdwn\b}{}xsm
    ){
        $version = '0+svn';
        $uri =~ m,^\?(?:\S+[&;])?rev=(\d+)(?:[&;]\S+)?$,
          and $version = "$version~$1";
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

    $self->hint('unknown-copyright-format-uri', $original_uri);

    return;
}

sub check_dep5_copyright {
    my ($self, $copyright_file) = @_;

    my $contents = $copyright_file->decoded_utf8;

    if ($contents =~ /^Files-Excluded:/m) {

        if ($contents
            =~ m{^Format:.*/doc/packaging-manuals/copyright-format/1.0/?$}m) {

            $self->hint('repackaged-source-not-advertised')
              unless $self->processable->repacked
              || $self->processable->native;

        } else {
            $self->hint('files-excluded-without-copyright-format-1.0',
                $copyright_file->name);
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

        $self->hint('no-dep5-copyright', $copyright_file->name);
        return;
    }

    # get format before parsing as a debian control file
    my $first_para = $contents;
    $first_para =~ s,^#.*,,mg;
    $first_para =~ s,[ \t]+$,,mg;
    $first_para =~ s,^\n+,,g;
    $first_para =~ s,\n\n.*,\n,s;    #;; hi emacs
    $first_para =~ s,\n?[ \t]+, ,g;

    $first_para =~ m,^Format(?:-Specification)?:\s*(.*),mi;
    my $uri = $1;

    unless (length $uri) {
        $self->hint('unknown-copyright-format-uri');
        return;
    }

    # strip fragment identifier
    $uri =~ s/^([^#\s]+)#/$1/;

    my $version = $self->find_dep5_version($uri);
    return
      unless defined $version;

    if ($version =~ /wiki/) {
        $self->hint('wiki-copyright-format-uri', $uri);

    } elsif ($version =~ /svn$/) {
        $self->hint('unversioned-copyright-format-uri', $uri);

    } elsif (versions_compare($version, '<<', $LAST_SIGNIFICANT_DEP5_CHANGE)) {
        $self->hint('out-of-date-copyright-format-uri', $uri);

    } elsif ($uri =~ m,^http://www\.debian\.org/,) {
        $self->hint('insecure-copyright-format-uri', $uri);
    }

    return
      if versions_compare($version, '<<', $LAST_DEP5_OVERHAUL);

    # probably DEP 5 format; let's try more checks
    my $deb822 = Lintian::Deb822::File->new;

    my @sections;
    eval { @sections = $deb822->parse_string($contents); };

    if (length $@) {
        chomp $@;

        $@ =~ s/^syntax error in //;
        $self->hint('syntax-error-in-dep5-copyright',
            $copyright_file->name . COLON . SPACE . $@);

        return;
    }

    return
      unless @sections;

    my %found_standalone;
    my %license_names_by_section;
    my %license_text_by_section;
    my %license_identifier_by_section;

    my @license_sections = grep { $_->exists('License') } @sections;
    for my $section (@license_sections) {

        $self->hint('tab-in-license-text',
            'debian/copyright (starting at line '
              . $section->position('License') . ')')
          if $section->untrimmed_value('License') =~ /\t/;

        my ($anycase_identifier, $license_text)
          = split(/\n/, $section->untrimmed_value('License'), 2);

        $anycase_identifier //= EMPTY;
        $license_text //= EMPTY;

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

        $self->hint(
            'empty-short-license-in-dep5-copyright',
            '(line ' . $section->position('License') . ')'
        )unless length $license_identifier;

        $self->hint('pipe-symbol-used-as-license-disjunction',
            $license_identifier,'(line '. $section->position('License') . ')')
          if $license_identifier =~ m{\s+\|\s+};

        for my $name (@license_names) {
            if ($name =~ m,\s,) {

                if($name =~ m,[^ ]+ \s+ with \s+ (.*),x) {
                    my $exceptiontext = $1;
                    unless ($exceptiontext =~ m,[^ ]+ \s+ exception,x) {
                        $self->hint('bad-exception-format-in-dep5-copyright',
                            $name,
                            '(line ' . $section->position('License') . ')');
                    }

                }else {
                    $self->hint('space-in-std-shortname-in-dep5-copyright',
                        $name,'(line ' . $section->position('License') . ')');
                }
            }

            $self->hint('invalid-short-name-in-dep5-copyright',
                $name,'(line ' . $section->position('License') . ')')
              if $name =~ m{^(?:agpl|gpl|lgpl)[^-]?\d(?:\.\d)?\+?$}
              || $name =~ m{^bsd(?:[^-]?[234][^-]?(?:clause|cluase))?$};

            $self->hint('license-problem-undefined-license',
                $name,'(line ' . $section->position('License') . ')')
              if $name =~ /^-$/
              || $name
              =~ m{\b(?:fixmes?|todos?|undefined?|unknown?|unspecified)\b};
        }

        # stand-alone license
        if (   length $license_identifier
            && length $license_text
            && !$section->exists('Files')) {
            $found_standalone{$license_identifier} //= [];
            push(@{$found_standalone{$license_identifier}}, $section);
        }

        if ($license_identifier =~ /^cc-/ && length $license_text) {

            my $num_lines = $license_text =~ tr/\n//;

            $self->hint('incomplete-creative-commons-license',
                $license_identifier,
                '(line ' . $section->position('License') . ')')
              if $num_lines < 20;
        }
    }

    my @not_unique
      = grep { @{$found_standalone{$_}} > 1 } keys %found_standalone;
    for my $name (@not_unique) {

        next
          if $name eq 'public-domain';

        $self->hint('dep5-copyright-license-name-not-unique',
            $name,'(line ' . $_->position('License') . ')')
          for @{$found_standalone{$name}};
    }

    my ($header, @followers) = @sections;

    my @obsolete_fields = grep { $header->exists($_) } keys %NEW_FIELD_NAMES;
    for my $old_name (@obsolete_fields) {

        $self->hint(
            'obsolete-field-in-dep5-copyright',
            $old_name,
            $NEW_FIELD_NAMES{$old_name},
            '(line ' . $header->position($old_name) . ')'
        );
    }

    $self->hint('copyright-excludes-files-in-native-package')
      if $header->exists('Files-Excluded')
      && $self->processable->native;

    unless ($self->processable->native) {

        my @orig_files
          = grep { $_->is_file } $self->processable->orig->sorted_list;
        my @orig_names = map { $_->name } @orig_files;

        my @wildcards = $header->trimmed_list('Files-Excluded');

        for my $wildcard (@wildcards) {

            my @offenders = escape_errors($wildcard);
            $self->hint('invalid-escape-sequence-in-dep5-copyright', $_)
              for @offenders;

            next
              if @offenders;

            # also match dir/filename for Files-Excluded: dir
            unless ($wildcard =~ /\*/ || $wildcard =~ /\?/) {

                my $candidate = $wildcard;
                $candidate .= SLASH
                  unless $candidate =~ m{/$};

                my $item = $self->processable->orig->lookup($candidate);

                $wildcard = $candidate . ASTERISK
                  if defined $item && $item->is_dir;
            }

            local $Text::Glob::strict_leading_dot = 0;
            local $Text::Glob::strict_wildcard_slash = 0;

            # disable Text::Glob character classes and alternations
            my $dulled = $wildcard;
            $dulled =~ s/([{}\[\]])/\\$1/g;

            my @unwanted = match_glob($dulled, @orig_names);

            for my $name (@unwanted) {

                $self->hint('source-includes-file-in-files-excluded', $name)
                  unless $name =~ m{^(?:debian|\.pc)/};
            }
        }
    }

    $self->hint('missing-field-in-dep5-copyright',
        'Format','(line ' . $header->position . ')')
      if none { $header->exists($_) } qw(Format Format-Specification);

    my $debian_control = $self->processable->debian_control;
    $self->hint('missing-explanation-for-contrib-or-non-free-package')
      if ($debian_control->source_fields->value('Section'))
      =~ m{^(?:contrib|non-free)(?:/.+)?$}
      && none { $header->exists($_) } qw(Comment Disclaimer);

    $self->hint('missing-explanation-for-repacked-upstream-tarball')
      if $self->processable->repacked
      && $header->value('Source') =~ m{^https?://}
      && none { $header->exists($_) } qw(Comment Files-Excluded);

    my @ambiguous_sections = grep {
             $_->exists('License')
          && $_->exists('Copyright')
          && !$_->exists('Files')
    } @followers;

    $self->hint(
        'ambiguous-paragraph-in-dep5-copyright',
        'paragraph at line ' . $_->position
    ) for @ambiguous_sections;

    my @unknown_sections
      = grep {!$_->exists('License')&& !$_->exists('Files')} @followers;

    $self->hint(
        'unknown-paragraph-in-dep5-copyright',
        'paragraph at line',
        $_->position
    ) for @unknown_sections;

    my @shipped_items;

    if ($self->processable->native) {
        @shipped_items = $self->processable->patched->sorted_list;

    } else {
        @shipped_items = $self->processable->orig->sorted_list;

        # remove ./debian folder from orig, if any
        @shipped_items = grep { $_ !~ m{^debian/} } @shipped_items
          if $self->processable->fields->value('Format') eq '3.0 (quilt)';

        # add ./ debian folder from patched
        my $debian_dir = $self->processable->patched->resolve_path('debian/');
        push(@shipped_items, $debian_dir->descendants)
          if $debian_dir;
    }

    my @shipped_names
      = sort map { $_->name } grep { $_->is_file } @shipped_items;

    my @license_names= grep { m,(^|/)(COPYING[^/]*|LICENSE)$, } @shipped_names;
    my @quilt_names = grep { m,^\.pc/, } @shipped_names;

    my @names_with_comma = grep { /,/ } @shipped_names;
    my @fields_with_comma = grep { $_->value('Files') =~ /,/ } @followers;

    if (@fields_with_comma && !@names_with_comma) {

        $self->hint(
            'comma-separated-files-in-dep5-copyright',
            'paragraph at line',
            $_->position('Files')) for @fields_with_comma;
    }

    # only attempt to evaluate globbing if commas could be legal
    my $check_wildcards = !@fields_with_comma || @names_with_comma;

    my @files_sections = grep {$_->exists('Files')} @followers;

    for my $section (@files_sections) {

        $self->hint('missing-field-in-dep5-copyright',
            'Files','(empty field, line ' . $section->position('Files') . ')')
          if $section->value('Files') =~ /^\s*$/;

        $self->hint('missing-field-in-dep5-copyright',
            'License', '(paragraph at line ' . $section->position . ')')
          unless $section->exists('License');

        $self->hint('missing-field-in-dep5-copyright',
            'Copyright','(paragraph at line ' . $section->position . ')')
          unless $section->exists('Copyright');

        $self->hint('missing-field-in-dep5-copyright',
            'Copyright',
            '(empty field, line ' . $section->position('Copyright') . ')')
          if $section->exists('Copyright')
          && $section->value('Copyright') =~ /^\s*$/;
    }

    my %sections_by_wildcard;
    my %wildcard_by_file;
    my %required_standalone;
    my @redundant_wildcards;

    my $section_count = 0;
    for my $section (@followers) {

        my @license_names
          = @{$license_names_by_section{$section->position} // []};
        my $license_text = $license_text_by_section{$section->position};

        if ($section->exists('Files') && !length $license_text) {
            $required_standalone{$_} = $section for @license_names;
        }

        my @wildcards;

        # If it is the first paragraph, it might be an instance of
        # the (no-longer) optional "first Files-field".
        if (   $section_count == 0
            && $section->exists('License')
            && $section->exists('Copyright')
            && !$section->exists('Files')) {

            @wildcards = (ASTERISK);

        } else {
            @wildcards = $section->trimmed_list('Files');
        }

        for my $wildcard (@wildcards) {
            $sections_by_wildcard{$wildcard} //= [];
            push(@{$sections_by_wildcard{$wildcard}}, $section);
        }

        $self->hint(
            'global-files-wildcard-not-first-paragraph-in-dep5-copyright',
            '(line ' . $section->position('Files') . ')')
          if (any { $_ eq ASTERISK } @wildcards) && $section_count > 0;

        # stand-alone license paragraph
        $self->hint(
            'missing-license-text-in-dep5-copyright',
            $section->untrimmed_value('License'),
            '(line ' . $section->position('License') . ')'
          )
          if !@wildcards
          && $section->exists('License')
          && !length $license_text;

        next
          unless $check_wildcards;

        my %wildcards_same_section_by_file;

        for my $wildcard (@wildcards) {

            my @offenders = escape_errors($wildcard);

            $self->hint(
                'invalid-escape-sequence-in-dep5-copyright',
                $_. ' (paragraph at line '. $section->position. ')'
            ) for @offenders;

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
              = @{$wildcards_same_section_by_file{$name}}[-1];
            my $loosing_wildcard = $wildcard_by_file{$name};

            my $winner_depth = ($winning_wildcard =~ tr{/}{});
            my $looser_depth = ($loosing_wildcard =~ tr{/}{});

            $self->hint('globbing-patterns-out-of-order',
                $loosing_wildcard, $winning_wildcard)
              if $looser_depth > $winner_depth;
        }

        # later matches have precendence; depends on section ordering
        $wildcard_by_file{$_} = @{$wildcards_same_section_by_file{$_}}[-1]
          for keys %wildcards_same_section_by_file;

        my @overmatched_same_section
          = grep { @{$wildcards_same_section_by_file{$_}} > 1 }
          keys %wildcards_same_section_by_file;

        $self->hint(
            'redundant-globbing-patterns',
            LEFT_SQUARE
              . join(SPACE, @{$wildcards_same_section_by_file{$_}})
              . RIGHT_SQUARE,
            "for $_"
        ) for @overmatched_same_section;

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
            $self->hint('duplicate-globbing-patterns', $wildcard, 'in lines',
                map { $_->position('Files') }
                  @{$sections_by_wildcard{$wildcard}});
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
            $self->hint(
                'wildcard-matches-nothing-in-dep5-copyright',
                "$wildcard (line " . $_->position('Files') . ')'
            ) for @{$sections_by_wildcard{$wildcard}};
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
        @xml_searchspace = grep { $_ !~ m{t/} } @xml_searchspace
          if $self->processable->name eq 'lintian';

        for my $name (@xml_searchspace) {

            next
              if $name =~ '^\.pc/';

            next
              unless $name =~ /\.xml$/;

            my $parser = XML::LibXML->new;
            $parser->set_option('no_network', 1);

            my $file = $self->processable->patched->resolve_path($name);
            my $doc = eval {$parser->parse_file($file->unpacked_path);};
            next
              unless $doc;

            my @nodes = $doc->findnodes('/component/metadata_license');
            next
              unless @nodes;

            # take first one
            my $first = $nodes[0];
            next
              unless $first;

            my $seen = lc($first->firstChild->data // EMPTY);
            next
              unless $seen;

            my @wanted = @{$license_identifiers_by_file{$name}};
            my @mismatched = grep { $_ ne $seen } @wanted;

            $self->hint('inconsistent-appstream-metadata-license',
                $name, "($seen != $_)")
              for @mismatched;
        }

        my @no_license_needed = (@quilt_names, @license_names);
        my $unlicensed_lc
          = List::Compare->new(\@shipped_names, \@no_license_needed);
        my @license_needed = $unlicensed_lc->get_Lonly;

        my @not_covered
          = grep { !@{$sections_by_file{$_} // []} } @license_needed;

        $self->hint('file-without-copyright-information',$_) for @not_covered;

        my @all_positions
          = map { $_->position }
          uniq map { @{$_} } values %sections_by_wildcard;
        my @used_positions
          = map { $_->position } uniq map { @{$_} } values %sections_by_file;
        my $unused_lc = List::Compare->new(\@all_positions, \@used_positions);
        my @unused_positions = $unused_lc->get_Lonly;

        $self->hint('unused-file-paragraph-in-dep5-copyright',
            "paragraph at line $_")
          for @unused_positions;
    }

    my $standalone_lc= List::Compare->new([keys %required_standalone],
        [keys %found_standalone]);
    my @missing_standalone = $standalone_lc->get_Lonly;
    my @matched_standalone = $standalone_lc->get_intersection;
    my @unused_standalone = $standalone_lc->get_Ronly;

    $self->hint('missing-license-paragraph-in-dep5-copyright',
        $_,'(line '. $required_standalone{$_}->position('License') . ')')
      for @missing_standalone;

    for my $name (grep { $_ ne 'public-domain' } @unused_standalone) {

        $self->hint('unused-license-paragraph-in-dep5-copyright',
            $name,'(line ' . $_->position('License') . ')')
          for @{$found_standalone{$name}};
    }

    for my $name (@matched_standalone) {
        $self->hint('dep5-file-paragraph-references-header-paragraph',
            $name,
            '(line '. $required_standalone{$name}->position('Files') . ')')
          if all { $_ == $header } @{$found_standalone{$name}};
    }

    # license files do not require their own entries in d/copyright.
    my $license_lc
      = List::Compare->new(\@license_names, [keys %sections_by_wildcard]);
    my @listed_licences = $license_lc->get_intersection;

    $self->hint('license-file-listed-in-debian-copyright',$_)
      for @listed_licences;

    return;
}

sub escape_errors {
    my ($escaped) = @_;

    my @sequences = ($escaped =~ m{\\.?}g);
    my @illegal = grep { $_ !~ m{^\\[*?]$} } @sequences;

    return @illegal;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

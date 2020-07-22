# copyright -- lintian check script -*- perl -*-

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

package Lintian::debian::copyright;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use List::MoreUtils qw(any all none uniq);
use Path::Tiny;
use Unicode::UTF8 qw[valid_utf8 decode_utf8];
use XML::LibXML;

use Lintian::Data;
use Lintian::Deb822::Parser qw(parse_dpkg_control_string);
use Lintian::Relation::Version qw(versions_compare);
use Lintian::Spelling qw(check_spelling);

use constant {
    WC_TYPE_REGEX => 'REGEX',
    WC_TYPE_FILE => 'FILE',
    WC_TYPE_DESCENDANTS => 'DESCENDANTS',
};

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant ASTERISK => q{*};
use constant QUESTION_MARK => q{?};
use constant BACKSLASH => q{\\};

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $KNOWN_ESSENTIAL = Lintian::Data->new('fields/essential');
our $KNOWN_COMMON_LICENSES
  =  Lintian::Data->new('copyright-file/common-licenses');

my $dep5_last_normative_change = '0+svn~166';
my $dep5_last_overhaul         = '0+svn~148';
my %dep5_renamed_fields        = (
    'Format-Specification' => 'Format',
    'Maintainer'           => 'Upstream-Contact',
    'Upstream-Maintainer'  => 'Upstream-Contact',
    'Contact'              => 'Upstream-Contact',
    'Name'                 => 'Upstream-Name',
);

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->tag(@orig_args, @_);
    };
}

sub source {
    my ($self) = @_;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless defined $debian_dir;

    my @installables = $self->processable->debian_control->installables;
    my @additional = map { $_ . '.copyright' } @installables;

    my @candidates = ('copyright', @additional);
    my @files = grep { defined } map { $debian_dir->child($_) } @candidates;

    # look for <pkgname>.copyright for a single installable
    if (@files == 1) {
        my $single = $files[0];

        $self->tag('named-copyright-for-single-installable', $single->name)
          unless $single->name eq 'debian/copyright';
    }

    $self->tag('no-debian-copyright-in-source')
      unless @files;

    my @symlinks = grep { $_->is_symlink } @files;
    $self->tag('debian-copyright-is-symlink', $_->name) for @symlinks;

    # another check complains about legacy encoding, if needed
    my @valid_utf8 = grep { $_->is_valid_utf8 } @files;

    $self->check_dep5_copyright($_)for @valid_utf8;

    $self->check_apache_notice_files($_)for @valid_utf8;

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
        $self->tag('boilerplate-copyright-format-uri', $uri);
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

    $self->tag('unknown-copyright-format-uri', $original_uri);

    return;
}

sub check_apache_notice_files {
    my ($self, $file) = @_;

    my $contents = $file->decoded_utf8;
    return
      unless $contents =~ /apache[-\s]+2\./i;

    my @notice_files = grep {
              $_->basename =~ /^NOTICE(\.txt)?$/
          and $_->is_open_ok
          and $_->bytes =~ /apache/i
    } $self->processable->patched->sorted_list;
    return
      unless @notice_files;

    my @binaries = $self->group->get_processables('binary');
    return
      unless @binaries;

    for my $binary (@binaries) {

        # look at all path names in the package
        my @names = map { $_->name } $binary->installed->sorted_list;

        # and also those shipped in jars
        my @jars = grep { scalar keys %{$_->java_info} }
          $binary->installed->sorted_list;
        push(@names, keys %{$_->java_info->{files}})for @jars;

        return
          if any { m{/NOTICE(\.txt)?(\.gz)?$} } @names;
    }

    $self->tag('missing-notice-file-for-apache-license',
        join(SPACE, @notice_files));

    return;
}

sub check_dep5_copyright {
    my ($self, $copyright_file) = @_;

    my $contents = $copyright_file->decoded_utf8;

    if ($contents =~ /^Files-Excluded:/m) {

        if ($contents
            =~ m{^Format:.*/doc/packaging-manuals/copyright-format/1.0/?$}m) {

            $self->tag('repackaged-source-not-advertised')
              unless $self->processable->repacked
              || $self->processable->native;

        } else {
            $self->tag('files-excluded-without-copyright-format-1.0',
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

        $self->tag('no-dep5-copyright', $copyright_file->name);
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
        $self->tag('unknown-copyright-format-uri');
        return;
    }

    # strip fragment identifier
    $uri =~ s/^([^#\s]+)#/$1/;

    my $version = $self->find_dep5_version($uri);
    return
      unless defined $version;

    if ($version =~ /wiki/) {
        $self->tag('wiki-copyright-format-uri', $uri);

    } elsif ($version =~ /svn$/) {
        $self->tag('unversioned-copyright-format-uri', $uri);

    } elsif (versions_compare($version, '<<', $dep5_last_normative_change)) {
        $self->tag('out-of-date-copyright-format-uri', $uri);

    } elsif ($uri =~ m,^http://www\.debian\.org/,) {
        $self->tag('insecure-copyright-format-uri', $uri);
    }

    return
      if versions_compare($version, '<<', $dep5_last_overhaul);

    $self->parse_dep5($copyright_file, $contents);

    return;
}

sub parse_dep5 {
    my ($self, $file, $contents) = @_;

    # probably DEP 5 format; let's try more checks
    my $deb822 = Lintian::Deb822::File->new;

    my @sections;
    eval { @sections = $deb822->parse_string($contents); };

    if (length $@) {
        chomp $@;

        $@ =~ s/^syntax error in //;
        $self->tag('syntax-error-in-dep5-copyright', "$file: $@");

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

        $self->tag('tab-in-license-text',
            'debian/copyright (starting at line '
              . $section->position('License') . ')')
          if $section->value('License') =~ /\t/;

        my ($anycase_identifier, $license_text)
          = split(/\n/, $section->value('License'), 2);

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

        $self->tag(
            'empty-short-license-in-dep5-copyright',
            '(line ' . $section->position('License') . ')'
        )unless length $license_identifier;

        $self->tag('pipe-symbol-used-as-license-disjunction',
            $license_identifier,'(line '. $section->position('License') . ')')
          if $license_identifier =~ m{\s+\|\s+};

        for my $name (@license_names) {
            if ($name =~ m,\s,) {

                if($name =~ m,[^ ]+ \s+ with \s+ (.*),x) {
                    my $exceptiontext = $1;
                    unless ($exceptiontext =~ m,[^ ]+ \s+ exception,x) {
                        $self->tag('bad-exception-format-in-dep5-copyright',
                            $name,
                            '(line ' . $section->position('License') . ')');
                    }

                }else {
                    $self->tag('space-in-std-shortname-in-dep5-copyright',
                        $name,'(line ' . $section->position('License') . ')');
                }
            }

            $self->tag('invalid-short-name-in-dep5-copyright',
                $name,'(line ' . $section->position('License') . ')')
              if $name =~ m{^(?:agpl|gpl|lgpl)[^-]?\d(?:\.\d)?\+?$}
              || $name =~ m{^bsd(?:[^-]?[234][^-]?(?:clause|cluase))?$};

            $self->tag('license-problem-undefined-license',
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

            $self->tag('incomplete-creative-commons-license',
                $license_identifier,
                '(line ' . $section->position('License') . ')')
              if $num_lines < 20;
        }
    }

    for my $name (
        grep { $_ ne 'public-domain' }
        grep { @{$found_standalone{$_}} > 1 } keys %found_standalone
    ) {

        $self->tag('dep5-copyright-license-name-not-unique',
            $name,'(line ' . $_->position('License') . ')')
          for @{$found_standalone{$name}};
    }

    my ($header, @followers) = @sections;

    my @obsolete = $header->present(keys %dep5_renamed_fields);
    for my $name (@obsolete) {

        my $position = $header->position($name);
        $self->tag(
            'obsolete-field-in-dep5-copyright',
            $name,
            $dep5_renamed_fields{$name},
            "(line $position)"
        );
    }

    $self->tag('copyright-excludes-files-in-native-package')
      if $header->exists('Files-Excluded')
      && $self->processable->native;

    unless ($self->processable->native) {

        my @files = grep { $_->is_file } $self->processable->orig->sorted_list;

        my @wildcards = $header->trimmed_list('Files-Excluded');

        for my $wildcard (@wildcards) {

            my ($wc_value, $wc_type, $wildcard_error)
              = parse_wildcard($wildcard);

            if (defined $wildcard_error) {
                $self->tag('invalid-escape-sequence-in-dep5-copyright',
                    $wildcard_error);
                next;
            }

            # also match dir/filename for Files-Excluded: dir
            $wc_value = qr{^$wc_value(?:/|$)}
              if $wc_type eq WC_TYPE_FILE;

            for my $srcfile (@files) {

                next
                  if $srcfile =~ m{^(?:debian|\.pc)/};

                $self->tag('source-includes-file-in-files-excluded', $srcfile)
                  if $srcfile =~ qr{^$wc_value};
            }
        }
    }

    $self->tag('missing-field-in-dep5-copyright',
        'Format','(line ' . $header->position . ')')
      if $header->present(qw(Format Format-Specification)) == 0;

    my $debian_control = $self->processable->debian_control;
    $self->tag('missing-explanation-for-contrib-or-non-free-package')
      if ($debian_control->source_fields->value('Section'))
      =~ m{^(?:contrib|non-free)(?:/.+)?$}
      && $header->present(qw(Comment Disclaimer)) == 0;

    $self->tag('missing-explanation-for-repacked-upstream-tarball')
      if $self->processable->repacked
      && $header->present(qw(Comment Files-Excluded)) == 0
      && $header->value('Source') =~ m{^https?://};

    my @ambiguous_sections = grep {
             $_->exists('License')
          && $_->exists('Copyright')
          && !$_->exists('Files')
    } @followers;

    $self->tag(
        'ambiguous-paragraph-in-dep5-copyright',
        'paragraph at line ' . $_->position
    ) for @ambiguous_sections;

    my @unknown_sections
      = grep {!$_->exists('License')&& !$_->exists('Files')} @followers;

    $self->tag(
        'unknown-paragraph-in-dep5-copyright',
        'paragraph at line',
        $_->position
    ) for @unknown_sections;

    my $index;
    if ($self->processable->native) {
        $index = $self->processable->patched;
    } else {
        $index = $self->processable->orig;
    }

    my @allpaths = $index->sorted_list;

    unless ($self->processable->native) {
        my $debian_dir = $self->processable->patched->resolve_path('debian/');
        push(@allpaths, $debian_dir->descendants)
          if $debian_dir;
    }

    my @shippedfiles = sort map { $_->name } grep { $_->is_file } @allpaths;

    my @licensefiles= grep { m,(^|/)(COPYING[^/]*|LICENSE)$, } @shippedfiles;
    my @quiltfiles = grep { m,^\.pc/, } @shippedfiles;

    my %file_shipped = map { $_ => 1 } @shippedfiles;

    my @names_with_comma = grep { /,/ } @allpaths;
    my @fields_with_comma = grep { $_->value('Files') =~ /,/ } @followers;

    if (@fields_with_comma && !@names_with_comma) {

        $self->tag(
            'comma-separated-files-in-dep5-copyright',
            'paragraph at line',
            $_->position('Files')) for @fields_with_comma;
    }

    # only attempt to evaluate globbing if commas could be legal
    my $check_wildcards = !@fields_with_comma || @names_with_comma;

    my @files_sections = grep {$_->exists('Files')} @followers;

    for my $section (@files_sections) {

        $self->tag('missing-field-in-dep5-copyright',
            'Files','(empty field, line ' . $section->position('Files') . ')')
          if $section->value('Files') =~ /^\s*$/;

        $self->tag('missing-field-in-dep5-copyright',
            'License', '(paragraph at line ' . $section->position . ')')
          unless $section->exists('License');

        $self->tag('missing-field-in-dep5-copyright',
            'Copyright','(paragraph at line ' . $section->position . ')')
          unless $section->exists('Copyright');

        $self->tag('missing-field-in-dep5-copyright',
            'Copyright',
            '(empty field, line ' . $section->position('Copyright') . ')')
          if $section->exists('Copyright')
          && $section->value('Copyright') =~ /^\s*$/;
    }

    my %section_by_wildcard;
    my %wildcard_by_file;
    my %required_standalone;

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

        $section_by_wildcard{$_} = $section for @wildcards;

        $self->tag(
            'global-files-wildcard-not-first-paragraph-in-dep5-copyright',
            '(line ' . $section->position('Files') . ')')
          if (any { $_ eq ASTERISK } @wildcards) && $section_count > 0;

        # stand-alone license paragraph
        $self->tag(
            'missing-license-text-in-dep5-copyright',
            $section->value('License'),
            '(line ' . $section->position('License') . ')'
          )
          if !@wildcards
          && $section->exists('License')
          && !length $license_text;

        next
          unless $check_wildcards;

        for my $wildcard (@wildcards) {

            my ($wc_value, $wc_type, $wildcard_error)
              = parse_wildcard($wildcard);

            if (defined $wildcard_error) {
                $self->tag('invalid-escape-sequence-in-dep5-copyright',
                        substr($wildcard_error, 0, 2)
                      . ' (paragraph at line '
                      . $section->position
                      . ')');
                next;
            }

            my @covered_files;

            if ($wc_type eq WC_TYPE_FILE) {
                @covered_files = ($wc_value)
                  if $file_shipped{$wc_value};

            } elsif ($wc_type eq WC_TYPE_DESCENDANTS) {

                # special-case Files: *
                if ($wc_value eq EMPTY) {
                    @covered_files = @shippedfiles;

                } elsif ($wc_value =~ /^debian\//) {
                    my $parent= $self->processable->patched->lookup($wc_value);
                    @covered_files= grep { $_->is_file }$parent->descendants
                      if $parent;

                } else {
                    my $parent = $index->lookup($wc_value);
                    @covered_files= grep { $_->is_file }$parent->descendants
                      if $parent;
                }

            } else {
                @covered_files = grep { $_ =~ $wc_value } @shippedfiles;
            }

            # later matches take priority; depends on section ordering
            $wildcard_by_file{$_} = $wildcard for @covered_files;
        }

    } continue {
        $section_count++;
    }

    if ($check_wildcards) {

        my $wildcard_lc = List::Compare->new([keys %section_by_wildcard],
            [values %wildcard_by_file]);
        my @matches_nothing = $wildcard_lc->get_Lonly;

        $self->tag('wildcard-matches-nothing-in-dep5-copyright',
            "$_ (line " . $section_by_wildcard{$_}->position('Files') . ')')
          for @matches_nothing;

        my %section_by_file;
        $section_by_file{$_} = $section_by_wildcard{$wildcard_by_file{$_}}
          for keys %wildcard_by_file;

        my %license_identifier_by_file;
        $license_identifier_by_file{$_}
          = $license_identifier_by_section{$section_by_file{$_}->position}
          for keys %section_by_file;

        my @xml_searchspace = keys %license_identifier_by_file;

        # do not search Lintian's test suite for appstream metadata
        @xml_searchspace = grep { $_ !~ m{t/} } @xml_searchspace
          if $self->processable->name eq 'lintian';

        for my $srcfile (@xml_searchspace) {
            next
              if $srcfile =~ '^\.pc/';
            next
              unless $srcfile =~ /\.xml$/;

            my $parser = XML::LibXML->new;
            $parser->set_option('no_network', 1);

            my $file = $self->processable->patched->resolve_path($srcfile);
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

            my $wanted = $license_identifier_by_file{$srcfile};

            $self->tag('inconsistent-appstream-metadata-license',
                $srcfile,"($seen != $wanted)")
              unless $seen eq $wanted;
        }

        my @no_license_needed = (@quiltfiles, @licensefiles);
        my $unlicensed_lc
          = List::Compare->new(\@shippedfiles, \@no_license_needed);
        my @license_needed = $unlicensed_lc->get_Lonly;

        my @files_not_covered = grep { !$section_by_file{$_} } @license_needed;

        $self->tag('file-without-copyright-information',$_)
          for @files_not_covered;

        my @all_positions
          = map { $_->position } uniq values %section_by_wildcard;
        my @used_positions = map { $_->position } uniq values %section_by_file;
        my $unused_lc = List::Compare->new(\@all_positions, \@used_positions);
        my @unused_positions = $unused_lc->get_Lonly;

        $self->tag('unused-file-paragraph-in-dep5-copyright',
            "paragraph at line $_")
          for @unused_positions;
    }

    my $standalone_lc= List::Compare->new([keys %required_standalone],
        [keys %found_standalone]);
    my @missing_standalone = $standalone_lc->get_Lonly;
    my @matched_standalone = $standalone_lc->get_intersection;
    my @unused_standalone = $standalone_lc->get_Ronly;

    $self->tag('missing-license-paragraph-in-dep5-copyright',
        $_,'(line '. $required_standalone{$_}->position('License') . ')')
      for @missing_standalone;

    for my $name (grep { $_ ne 'public-domain' } @unused_standalone) {
        $self->tag('unused-license-paragraph-in-dep5-copyright',
            $name,'(line ' . $_->position('License') . ')')
          for @{$found_standalone{$name}};
    }

    for my $name (@matched_standalone) {
        $self->tag('dep5-file-paragraph-references-header-paragraph',
            $name,
            '(line '. $required_standalone{$name}->position('Files') . ')')
          if all { $_ == $header } @{$found_standalone{$name}};
    }

    # license files do not require their own entries in d/copyright.
    my $license_lc
      = List::Compare->new(\@licensefiles, [keys %section_by_wildcard]);
    my @listedlicensefiles = $license_lc->get_intersection;

    $self->tag('license-file-listed-in-debian-copyright',$_)
      for @listedlicensefiles;

    return;
}

sub dequote_backslashes {
    my ($string) = @_;

    return ($string, undef)
      if index($string, BACKSLASH) == -1;

    my $error;
    eval {
        $string =~ s{
            ([^\\]+) |
            (\\[\\]) |
            (.+)
        }{
            if (defined $1) {
                quotemeta($1);
            } elsif (defined $2) {
                $2;
            } else {
                $error = $3;
                die;
            }
        }egx;
    };

    if ($@) {
        return (undef, $error);
    }

    return ($string, undef);
}

sub parse_wildcard {
    my ($regex_src) = @_;

    return (EMPTY, WC_TYPE_DESCENDANTS, undef)
      if $regex_src eq ASTERISK;

    my $error;

    if (index($regex_src, QUESTION_MARK) == -1) {

        my $star_index = index($regex_src, ASTERISK);

        if ($star_index == -1) {
            # Regular file-match, dequote "\\" if any and stop here.
            ($regex_src, $error) = dequote_backslashes($regex_src);

            return ($regex_src, WC_TYPE_FILE, $error);
        }

        if ($star_index + 1 == length $regex_src
            && substr($regex_src, -2) eq '/*') {
            # Files: some-dir/*
            $regex_src = substr($regex_src, 0, -1);

            ($regex_src, $error) = dequote_backslashes($regex_src);

            return ($regex_src, WC_TYPE_DESCENDANTS, $error);
        }
    }

    eval {
        $regex_src =~ s{
            (\*) |
            (\?) |
            ([^*?\\]+) |
            (\\[\\*?]) |
            (.+)
        }{
            if (defined $1) {
                '.*';
            } elsif (defined $2) {
                '.'
            } elsif (defined $3) {
                quotemeta($3);
            } elsif (defined $4) {
                $4;
            } else {
                $error = $5;
                die;
            }
        }egx;
    };
    if ($@) {
        return (undef, undef, $error);
    } else {
        return (qr/^(?:$regex_src)$/, WC_TYPE_REGEX, undef);
    }
}

# no copyright in udebs
sub binary {
    my ($self) = @_;

    # looking up entry without slash first; index should not be so picky
    my $doclink = $self->processable->installed->lookup(
        'usr/share/doc/' . $self->processable->name);
    if ($doclink && $doclink->is_symlink) {

        # check if this symlink references a directory elsewhere
        if ($doclink->link =~ m{^(?:\.\.)?/}s) {
            $self->tag('usr-share-doc-symlink-points-outside-of-usr-share-doc',
                $doclink->link);
            return;
        }

        # The symlink may point to a subdirectory of another
        # /usr/share/doc directory.  This is allowed if this
        # package depends on link and both packages come from the
        # same source package.
        #
        # Policy requires that packages be built from the same
        # source if they're going to do this, which by my (rra's)
        # reading means that we should have a strict version
        # dependency.  However, in practice the copyright file
        # doesn't change a lot and strict version dependencies
        # cause other problems (such as with arch: any / arch: all
        # package combinations and binNMUs).
        #
        # We therefore just require the dependency for now and
        # don't worry about the version number.
        my $link = $doclink->link;
        $link =~ s,/.*,,;

        unless (depends_on($self->processable, $link)) {
            $self->tag('usr-share-doc-symlink-without-dependency', $link);

            return;
        }

        # Check if the link points to a package from the same source.
        $self->check_cross_link($link);

        return;
    }

    my $docdir = $self->processable->installed->lookup(
        'usr/share/doc/' . $self->processable->name . '/');
    unless ($docdir) {
        $self->tag('no-copyright-file');
        return;
    }

    my $found = 0;
    if ($docdir->child('copyright.gz')) {
        $self->tag('copyright-file-compressed');
        $found = 1;
    }

    my $linked = 0;

    my $file = $docdir->child('copyright');
    if ($file) {
        $found = 1;

        if ($file->is_symlink) {
            $self->tag('copyright-file-is-symlink');
            $linked = 1;
         # fall through; coll/copyright-file prevents reading through evil link
        }
    }

    unless ($found) {

        # #522827: special exception for perl for now
        $self->tag('no-copyright-file')
          unless $self->processable->name eq 'perl';

        return;
    }

    my $dcopy
      = path($self->processable->groupdir)->child('copyright')->stringify;

    my $bytes = path($dcopy)->slurp;

    # another check complains about invalid encoding
    return
      unless valid_utf8($bytes);

    # check contents of copyright file
    my $contents = decode_utf8($bytes);

    $self->tag('copyright-has-crs')
      if $contents =~ /\r/;

    my $wrong_directory_detected = 0;

    if ($contents =~ m{ (usr/share/common-licenses/ ( [^ \t]*? ) \.gz) }xsm) {
        my ($path, $license) = ($1, $2);
        if ($KNOWN_COMMON_LICENSES->known($license)) {
            $self->tag('copyright-refers-to-compressed-license', $path);
        }
    }

    # Avoid complaining about referring to a versionless license file
    # if the word "version" appears nowhere in the copyright file.
    # This won't catch all of our false positives for GPL references
    # that don't include a specific version number, but it will get
    # the obvious ones.
    if ($contents =~ m,(usr/share/common-licenses/(L?GPL|GFDL))([^-]),i) {
        my ($ref, $license, $separator) = ($1, $2, $3);
        if ($separator =~ /[\d\w]/) {
            $self->tag('copyright-refers-to-nonexistent-license-file',
                "$ref$separator");
        } elsif ($contents =~ m,\b(?:any|or)\s+later(?:\s+version)?\b,i
            || $contents =~ m,License: $license-[\d\.]+\+,i
            || $contents =~ m,as Perl itself,i
            || $contents =~ m,License-Alias:\s+Perl,
            || $contents =~ m,License:\s+Perl,) {
            $self->tag('copyright-refers-to-symlink-license', $ref);
        } else {
            $self->tag('copyright-refers-to-versionless-license-file', $ref)
              if $contents =~ /\bversion\b/;
        }
    }

    # References to /usr/share/common-licenses/BSD are deprecated as of Policy
    # 3.8.5.
    if ($contents =~ m,/usr/share/common-licenses/BSD,) {
        $self->tag('copyright-refers-to-deprecated-bsd-license-file');
    }

    if ($contents =~ m,(usr/share/common-licences),) {
        $self->tag('copyright-refers-to-incorrect-directory', $1);
        $wrong_directory_detected = 1;
    }

    if ($contents =~ m,usr/share/doc/copyright,) {
        $self->tag('copyright-refers-to-old-directory');
        $wrong_directory_detected = 1;
    }

    if ($contents =~ m,usr/doc/copyright,) {
        $self->tag('copyright-refers-to-old-directory');
        $wrong_directory_detected = 1;
    }

    # Lame check for old FSF zip code.  Try to avoid false positives from other
    # Cambridge, MA addresses.
    if ($contents =~ m/(?:Free\s*Software\s*Foundation.*02139|02111-1307)/s) {
        $self->tag('old-fsf-address-in-copyright-file');
    }

    # Whether the package is covered by the GPL, used later for the
    # libssl check.
    my $gpl;

    if (
        length($contents) > 12_000
        and (
            $contents =~m/  \b \QGNU GENERAL PUBLIC LICENSE\E \s*
                    \QTERMS AND CONDITIONS FOR COPYING,\E \s*
                    \QDISTRIBUTION AND MODIFICATION\E\b/mx
            or (    $contents =~ m/\bGNU GENERAL PUBLIC LICENSE\s*Version 3/
                and $contents =~ m/\bTERMS AND CONDITIONS\s/))
    ) {
        $self->tag('copyright-file-contains-full-gpl-license');
        $gpl = 1;
    }

    if (    length($contents) > 12_000
        and $contents =~ m/\bGNU Free Documentation License\s*Version 1\.2/
        and $contents =~ m/\b1\. APPLICABILITY AND DEFINITIONS/) {
        $self->tag('copyright-file-contains-full-gfdl-license');
    }

    if (    length($contents) > 10_000
        and $contents =~ m/\bApache License\s+Version 2\.0,/
        and $contents
        =~ m/TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION/) {
        $self->tag('copyright-file-contains-full-apache-2-license');
    }

    # wtf?
    if (   ($contents =~ m,common-licenses(/\S+),)
        && ($contents !~ m,/usr/share/common-licenses/,)) {
        $self->tag('copyright-does-not-refer-to-common-license-file', $1);
    }

    # This check is a bit prone to false positives, since some other
    # licenses mention the GPL.  Also exclude any mention of the GPL
    # following what looks like mail header fields, since sometimes
    # e-mail discussions of licensing are included in the copyright
    # file but aren't referring to the license of the package.
    unless (
           $contents =~ m,/usr/share/common-licenses,
        || $contents =~ m/Zope Public License/
        || $contents =~ m/LICENSE AGREEMENT FOR PYTHON 1.6.1/
        || $contents =~ m/LaTeX Project Public License/
        || $contents
        =~ m/(?:^From:.*^To:|^To:.*^From:).*(?:GNU General Public License|GPL)/ms
        || $contents =~ m/AFFERO GENERAL PUBLIC LICENSE/
        || $contents =~ m/GNU Free Documentation License[,\s]*Version 1\.1/
        || $contents =~ m/CeCILL FREE SOFTWARE LICENSE AGREEMENT/ #v2.0
        || $contents =~ m/FREE SOFTWARE LICENSING AGREEMENT CeCILL/ #v1.1
        || $contents =~ m/CNRI OPEN SOURCE GPL-COMPATIBLE LICENSE AGREEMENT/
        || $contents =~ m/compatible\s+with\s+(?:the\s+)?(?:GNU\s+)?GPL/
        || $contents =~ m/(?:GNU\s+)?GPL\W+compatible/
        || $contents
        =~ m/was\s+previously\s+(?:distributed\s+)?under\s+the\s+GNU/
        || $contents
        =~ m/means\s+either\s+the\s+GNU\s+General\s+Public\s+License/
        || $wrong_directory_detected
    ) {
        if (
            check_names_texts(
                $contents,
                qr/\b(?:GFDL|gnu[-_]free[-_]documentation[-_]license)\b/i,
                qr/GNU Free Documentation License|(?-i:\bGFDL\b)/i
            )
        ) {
            $self->tag('copyright-not-using-common-license-for-gfdl');
        }elsif (
            check_names_texts(
                $contents,
qr/\b(?:LGPL|gnu[-_](?:lesser|library)[-_]general[-_]public[-_]license)\b/i,
qr/GNU (?:Lesser|Library) General Public License|(?-i:\bLGPL\b)/i
            )
        ) {
            $self->tag('copyright-not-using-common-license-for-lgpl');
        }elsif (
            check_names_texts(
                $contents,
                qr/\b(?:GPL|gnu[-_]general[-_]public[-_]license)\b/i,
                qr/GNU General Public License|(?-i:\bGPL\b)/i
            )
        ) {
            $self->tag('copyright-not-using-common-license-for-gpl');
            $gpl = 1;
        }elsif (
            check_names_texts(
                $contents,qr/\bapache[-_]2/i,
                qr/\bApache License\s*,?\s*Version 2|\b(?-i:Apache)-2/i
            )
        ) {
            $self->tag('copyright-not-using-common-license-for-apache2');
        }
    }

    if (
        check_names_texts(
            $contents,
            qr/\b(?:perl|artistic)\b/,
            sub {
                my ($contents) = @_;
                $contents
                  =~ /(?:under )?(?:the )?(?:same )?(?:terms )?as Perl itself\b/i
                  && $contents !~ m,usr/share/common-licenses/,;
            })
    ) {
        $self->tag('copyright-file-lacks-pointer-to-perl-license');
    }

    # Checks for various packaging helper boilerplate.

    if (
           $contents =~ m,\<fill in (?:http/)?ftp site\>,
        or $contents =~ m,\<Must follow here\>,
        or $contents =~ m,\<Put the license of the package here,
        or $contents =~ m,\<put author[\'\(]s\)? name and email here\>,
        or $contents =~ m,\<Copyright \(C\) YYYY Name OfAuthor\>,
        or $contents =~ m,Upstream Author\(s\),
        or $contents =~ m,\<years\>,
        or $contents =~ m,\<special license\>,
        or $contents
        =~ m,\<Put the license of the package here indented by 1 space\>,
        or $contents=~ m,\Q<This follows the format of Description: lines\E \s*
             \Qin control file>\E,x
        or $contents =~ m,\<Including paragraphs\>,
        or $contents =~ m,\<likewise for another author\>,
    ) {
        $self->tag('helper-templates-in-copyright');
    }

    # dh-make-perl
    if ($contents =~ m/This copyright info was automatically extracted/) {
        $self->tag('copyright-contains-automatically-extracted-boilerplate');
    }
    if ($contents =~ m,\<INSERT COPYRIGHT YEAR\(S\) HERE\>,) {
        $self->tag('helper-templates-in-copyright');
    }

    if ($contents =~ m,url://,) {
        $self->tag('copyright-has-url-from-dh_make-boilerplate');
    }

    # dh-make boilerplate
    my @dh_make_boilerplate = (
"\# Please also look if there are files or directories which have a\n\# different copyright/license attached and list them here.",
"\# If you want to use GPL v2 or later for the /debian/\* files use\n\# the following clauses, or change it to suit. Delete these two lines"
    );

    $self->tag('copyright-contains-dh_make-todo-boilerplate')
      if any { $contents =~ $_ } @dh_make_boilerplate;

    $self->tag('copyright-with-old-dh-make-debian-copyright')
      if $contents =~ m,The\s+Debian\s+packaging\s+is\s+\(C\)\s+\d+,i;

    # Other flaws in the copyright phrasing or contents.
    if ($found && !$linked) {
        $self->tag('copyright-without-copyright-notice')
          unless $contents
          =~ /(?:Copyright|Copr\.|©)(?:.*|[\(C\):\s]+)\b\d{4}\b
               |\bpublic(?:\s+|-)domain\b/xi;
    }

    check_spelling(
        $contents,
        $self->group->spelling_exceptions,
        $self->spelling_tag_emitter('spelling-error-in-copyright'), 0
    );

    # Now, check for linking against libssl if the package is covered
    # by the GPL.  (This check was requested by ftp-master.)  First,
    # see if the package is under the GPL alone and try to exclude
    # packages with a mix of GPL and LGPL or Artistic licensing or
    # with an exception or exemption.
    if (($gpl || $contents =~ m{/usr/share/common-licenses/GPL})
        &&$contents
        !~ m{exception|exemption|/usr/share/common-licenses/(?!GPL)\S}){

        my @depends
          = split(/\s*,\s*/,$self->processable->fields->value('Depends'));
        my @predepends
          = split(/\s*,\s*/,$self->processable->fields->value('Pre-Depends'));

        $self->tag('possible-gpl-code-linked-with-openssl')
          if any { /^libssl[0-9.]+(?:\s|\z)/ && !/\|/ }
        (@depends, @predepends);
    }

    return;
} # </run>

# -----------------------------------

# Returns true if the package whose information is in $processable depends $package
# or if $package is essential.
sub depends_on {
    my ($processable, $package) = @_;

    return 1
      if $KNOWN_ESSENTIAL->known($package);

    my $strong = $processable->relation('strong');
    return 1
      if $strong->implies($package);

    my $arch = $processable->architecture;
    return 1
      if $arch ne 'all' and $strong->implies("${package}:${arch}");

    return 0;
}

# Checks cross pkg links for /usr/share/doc/$pkg links
sub check_cross_link {
    my ($self, $foreign) = @_;

    my $source = $self->group->source;
    if ($source) {

        # source package is available; check its list of binaries
        return
          if any { $foreign eq $_ } $source->debian_control->installables;

        $self->tag('usr-share-doc-symlink-to-foreign-package', $foreign);

    } else {
        # The source package is not available, but the binary could
        # be present anyway;  If they are in the same group, they claim
        # to have the same source (and source version)
        return
          if any { $_->name eq $foreign }
        $self->group->get_processables('binary');

        # It was not, but since the source package was not present, we cannot
        # tell if it is foreign or not at this point.

        $self->tag(
'cannot-check-whether-usr-share-doc-symlink-points-to-foreign-package'
        );
    }

    return;
}

# Checks the name and text of every license in the file against given name and
# text check coderefs, if the file is in the new format, if the file is in the
# old format only runs the text coderef against the whole file.
sub check_names_texts {
    my ($contents, $name_check, $action) = @_;

    my $text_check;

    if ((ref($action) || '') eq 'Regexp') {
        $text_check = sub {
            my ($textref) = @_;
            return ${$textref} =~ $action;
        };

    } else {
        $text_check = sub {
            my ($textref) = @_;
            return $action->(${$textref});
        };
    }

    my @paragraphs;

    local $@;
    eval {@paragraphs = parse_dpkg_control_string($contents);};

    # parse error: copyright not in new format, just check text
    return $text_check->(\$contents)
      if $@;

    my @licenses = grep { length } map { $_->{License} } @paragraphs;
    for my $license (@licenses) {

        my ($name, $text) = ($license =~ /^\s*([^\r\n]+)\r?\n(.*)\z/s);

        next
          unless length $text;

        next
          if $text =~ /^[\s\r\n]*\z/;

        return 1
          if $name =~ $name_check
          && $text_check->(\$text);
    }

    # did not match anything
    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

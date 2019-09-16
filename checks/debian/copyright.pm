# copyright -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2011 Jakub Wilk
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

use strict;
use warnings;
use autodie;

use constant {
    DH_MAKE_TODO_BOILERPLATE_1 =>join(q{ },
        '# Please also look if there are files or directories',
        "which have a\n\# different copyright/license attached",
        'and list them here.'),
    DH_MAKE_TODO_BOILERPLATE_2 =>join(q{ },
        '# If you want to use GPL v2 or later for the /debian/\*',
        "files use\n\# the following clauses, or change it to suit.",
        'Delete these two lines'),
};

use Encode qw(decode);
use List::MoreUtils qw(any none);
use Path::Tiny;
use Text::Levenshtein qw(distance);
use XML::Simple qw(:strict);

use Lintian::Check qw(check_spelling spelling_tag_emitter);
use Lintian::Data;
use Lintian::Deb822Parser qw(read_dpkg_control parse_dpkg_control);
use Lintian::Relation::Version qw(versions_compare);
use Lintian::Tags qw(tag);
use Lintian::Util qw(file_is_encoded_in_non_utf8);

use constant {
    WC_TYPE_REGEX => 'REGEX',
    WC_TYPE_FILE => 'FILE',
    WC_TYPE_DECENDANTS => 'DECENDANTS',
};

our $KNOWN_ESSENTIAL = Lintian::Data->new('fields/essential');
our $KNOWN_COMMON_LICENSES
  =  Lintian::Data->new('copyright-file/common-licenses');

my $SPELLING_ERROR_IN_COPYRIGHT
  = spelling_tag_emitter('spelling-error-in-copyright');

my $BAD_SHORT_LICENSES = Lintian::Data->new(
    'source-copyright/bad-short-licenses',
    qr/\s*\~\~\s*/,
    sub {
        return {
            'regex' => qr/$_[0]/xms,
            'tag'   => $_[1],
        };
    });

my $dep5_last_normative_change = '0+svn~166';
my $dep5_last_overhaul         = '0+svn~148';
my %dep5_renamed_fields        = (
    'format-specification' => 'format',
    'maintainer'           => 'upstream-contact',
    'upstream-maintainer'  => 'upstream-contact',
    'contact'              => 'upstream-contact',
    'name'                 => 'upstream-name',
);

sub source {
    my (undef, undef, $info, undef, $group) = @_;
    my $debian_dir = $info->index_resolved_path('debian/');
    return if not $debian_dir;
    my $copyright_path = $debian_dir->child('copyright');

    if (not $copyright_path) {
        my @pkgs = $info->binaries;
        tag 'no-debian-copyright';
        if (scalar @pkgs == 1) {
            # If debian/copyright doesn't exist, and the only a single
            # binary package is built, there's a good chance that the
            # copyright file is available as
            # debian/<pkgname>.copyright.
            $copyright_path = $debian_dir->child($pkgs[0] . '.copyright');
        }
        return if not $copyright_path;
    } elsif ($copyright_path->is_symlink) {
        tag 'debian-copyright-is-symlink';
    }

    if ($copyright_path->is_open_ok) {
        my $contents = $copyright_path->file_contents;

        _check_dep5_copyright($info, $contents);
        _check_apache_notice_files($info, $group, $contents);
    }
    return;
}

# The policy states, since 4.0.0, that people should use "https://" for the
# format URI. This is checked later in check_dep5_copyright.
# return undef is not dep5 and '' if unknown version
sub _find_dep5_version {
    my ($original_uri) = @_;
    my $uri = $original_uri;
    my $version;

    if ($uri =~ m,\b(?:rev=REVISION|VERSIONED_FORMAT_URL)\b,) {
        tag 'boilerplate-copyright-format-uri', $uri;
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

    tag 'unknown-copyright-format-uri', $original_uri;
    return;
}

sub _check_apache_notice_files {
    my ($info, $group, $contents) = @_;

    my @procs = $group->get_processables('binary');
    return if not @procs;
    return if $contents !~ m/apache[-\s]+2\./i;

    my @notice_files = grep {
              $_->basename =~ m/^NOTICE(\.txt)?$/
          and $_->is_open_ok
          and $_->file_contents =~ m/apache/i
    } $info->sorted_index;
    return if not @notice_files;

    foreach my $binpkg (@procs) {
        my @files = map { $_->name } $binpkg->info->sorted_index;
        my $java_info = $binpkg->info->java_info;
        for my $jar_file (sort keys %{$java_info}) {
            push @files, keys %{$java_info->{$jar_file}{files}};
        }
        return if any { m{/NOTICE(\.txt)?(\.gz)?$} } @files;
    }

    tag 'missing-notice-file-for-apache-license', join(' ', @notice_files);

    return;
}

sub _check_dep5_copyright {
    my ($info, $contents) = @_;
    my (@dep5, @lines);

    if (    $contents =~ m/^Files-Excluded:/
        and $contents
        !~ m{^Format:.*/doc/packaging-manuals/copyright-format/1.0$}) {
        tag 'files-excluded-without-copyright-format-1.0';
    }

    if (
        $contents !~ m{
               (?:^ | \n)
               (?i: format(?: [:] |[-\s]spec) )
               (?: . | \n\s+ )*
               (?: /dep[5s]?\b | \bDEP ?5\b
                 | [Mm]achine-readable\s(?:license|copyright)
                 | /copyright-format/ | CopyrightFormat
                 | VERSIONED_FORMAT_URL
               ) }x
    ){

        tag 'no-dep5-copyright';
        return;
    }

    # Before trying to parse the copyright as Debian control file, try to
    # determine the format URI.
    my $first_para = $contents;
    $first_para =~ s,^#.*,,mg;
    $first_para =~ s,[ \t]+$,,mg;
    $first_para =~ s,^\n+,,g;
    $first_para =~ s,\n\n.*,\n,s;    #;; hi emacs
    $first_para =~ s,\n?[ \t]+, ,g;
    $first_para =~ m,^Format(?:-Specification)?:\s*(.*),mi;
    my $uri = $1;
    $uri =~ s/^([^#\s]+)#/$1/
      if defined $uri;               # strip fragment identifier

    if (!defined $uri) {
        tag 'unknown-copyright-format-uri';
        return;
    }

    my $version = _find_dep5_version($uri);

    return if !defined($version);
    if ($version =~ m,wiki,) {
        tag 'wiki-copyright-format-uri', $uri;
    }elsif ($version =~ m,svn$,) {
        tag 'unversioned-copyright-format-uri', $uri;
    }elsif (versions_compare $version, '<<', $dep5_last_normative_change) {
        tag 'out-of-date-copyright-format-uri', $uri;
    }elsif ($uri =~ m,^http://www\.debian\.org/,) {
        tag 'insecure-copyright-format-uri', $uri;
    }

    if (versions_compare $version, '<<', $dep5_last_overhaul) {
        return;
    }

    # We are reasonably certain that we're dealing
    # with an up-to-date DEP 5 format. Let's try to do
    # more strict checks.
    eval {
        open(my $fd, '<', \$contents);
        @dep5 = parse_dpkg_control($fd, 0, \@lines);
        close($fd);
    };
    if ($@) {
        chomp $@;
        $@ =~ s/^syntax error at //;
        tag 'syntax-error-in-dep5-copyright', $@;
        return;
    }

    return if (!@dep5);

    _parse_dep5($info, \@dep5, \@lines);

    return;
}

sub _parse_dep5 {
    my ($info, $dep5ref, $linesref) = @_;
    my @dep5       = @$dep5ref;
    my @lines      = @$linesref;
    my $first_para = shift @dep5;
    my %standalone_licenses;
    my %required_standalone_licenses;
    my %short_licenses_seen;
    my %full_licenses_seen;

    for my $field (keys %{$first_para}) {
        my $renamed_to = $dep5_renamed_fields{$field};
        if (defined $renamed_to) {
            tag 'obsolete-field-in-dep5-copyright', $field,
              $renamed_to, "(line $lines[0]{$field})";
        }
    }
    check_files_excluded($info, $first_para->{'files-excluded'} // '');

    tag 'missing-field-in-dep5-copyright', 'format',
      "(line $lines[0]{'format'})"
      if none { defined $first_para->{$_} } qw(format format-specification);
    tag 'missing-explanation-for-contrib-or-non-free-package'
      if $info->source_field('section', '') =~ m{^(contrib|non-free)(/.+)?$}
      and none { defined $first_para->{$_} } qw(comment disclaimer);
    tag 'missing-explanation-for-repacked-upstream-tarball'
      if $info->repacked
      and none { defined $first_para->{$_} } qw(comment files-excluded)
      and ($first_para->{'source'} // '') =~ m{^https?://};

    my (undef, $full_license_field, undef,@short_licenses_field)
      =parse_license($first_para->{'license'}, 1);
    for my $short_license (@short_licenses_field) {
        $required_standalone_licenses{$short_license} = 0
          if not defined($full_license_field);
        $short_licenses_seen{$short_license}          = 1;
    }
    if(defined($full_license_field)) {
        for (@short_licenses_field) {
            $standalone_licenses{$_} = -1;
            $full_licenses_seen{$_} = 1;
        }
    }

    my (@commas_in_files, %file_para_coverage, %file_licenses);
    my %file_coverage = map { $_ => 0 } get_all_files($info);
    my $i = 0;
    my $current_line = 0;
    my $commas_in_files = any { m/,/xsm } $info->sorted_index;
    for my $para (@dep5) {
        $i++;
        $current_line = $lines[$i]{'START-OF-PARAGRAPH'};
        my ($files_fname, $files)
          =get_field($para, 'files', $lines[$i]);
        my $license   = get_field($para, 'license',   $lines[$i]);
        my $copyright = get_field($para, 'copyright', $lines[$i]);

        if (    not defined $files
            and defined $license
            and defined $copyright){
            tag 'ambiguous-paragraph-in-dep5-copyright',
              "paragraph at line $current_line";

            # If it is the first paragraph, it might be an instance of
            # the (no-longer) optional "first Files-field".
            $files = '*' if $i == 1;
        }

        if (defined $license and not defined $files) {
            my (undef, $full_license, $short_license,@short_licenses)
              = parse_license($license, $current_line);
            check_incomplete_creative_commons_license($short_license,
                $license, $current_line);
            # Standalone license paragraph
            if (defined($short_license) and $short_license =~ /\s++\|\s++/) {
                tag 'pipe-symbol-used-as-license-disjunction', $short_license,
                  "(paragraph at line $current_line)";
            }
            if (not defined($full_license)) {
                tag 'missing-license-text-in-dep5-copyright', $license,
                  "(paragraph at line $current_line)";
            }else {
                for (@short_licenses) {
                    if(defined($full_licenses_seen{$_})
                        and $_ ne 'public-domain') {
                        tag 'dep5-copyright-license-name-not-unique',
                          "(paragraph at line $current_line)";
                    } else {
                        $standalone_licenses{$_} = $i;
                        $full_licenses_seen{$_} = $current_line;
                    }
                    $short_licenses_seen{$_} = $i;
                }
            }
        }elsif (defined $files) {
            if ($files =~ m/\A\s*\Z/mxs) {
                tag 'missing-field-in-dep5-copyright', 'files',
                  '(empty field,',
                  "paragraph at line $current_line)";
            }

            tag 'global-files-wildcard-not-first-paragraph-in-dep5-copyright',
              "(paragraph at line $current_line)"
              if $files eq '*' and $i > 1;

            # Files paragraph
            if (not @commas_in_files and $files =~ /,/) {
                @commas_in_files = ($i, $files_fname);
            }

            my ($found_license, $full_license, $short_license, @short_licenses)
              = parse_license($license, $current_line);

            # only attempt to evaluate globbing if commas could be legal
            if (not @commas_in_files or $commas_in_files) {
                my @wildcards = split /[\n\t ]+/, $files;
                for my $wildcard (@wildcards) {
                    $wildcard =~ s/^\s+|\s+$//g;
                    if ($wildcard eq '') {
                        next;
                    }
                    my ($wc_value, $wc_type, $wildcard_error)
                      = parse_wildcard($wildcard);
                    if (defined $wildcard_error) {
                        tag 'invalid-escape-sequence-in-dep5-copyright',
                          substr($wildcard_error, 0, 2)
                          . " (paragraph at line $current_line)";
                        next;
                    }

                    my $used = 0;
                    $file_para_coverage{$current_line} = 0;
                    if ($wc_type eq WC_TYPE_FILE) {
                        if (exists($file_coverage{$wc_value})) {
                            $used = 1;
                            $file_coverage{$wildcard} = $current_line;
                            $file_licenses{$wildcard} = $short_license;
                        }
                    } elsif ($wc_type eq WC_TYPE_DECENDANTS) {
                        my @wlist;
                        if (my $dir = $info->index($wc_value)) {
                            if ($wc_value eq q{}) {
                                # Special-case => Files: *
                                push(@wlist, get_all_files($info));
                            } else {
                                push(@wlist,
                                    grep { $_->is_file }
                                      $dir->children('breadth-first'));
                            }
                            $used = 1 if @wlist;
                        }
                        for my $entry (@wlist) {
                            $file_coverage{$entry->name} = $current_line;
                            $file_licenses{$entry->name} = $short_license;
                        }
                    } else {
                        for my $srcfile (keys %file_coverage) {
                            if ($srcfile =~ $wc_value) {
                                $used = 1;
                                $file_coverage{$srcfile} = $current_line;
                                $file_licenses{$srcfile} = $short_license;
                            }
                        }
                    }
                    if ($used) {
                        $file_para_coverage{$current_line} = 1;
                    } elsif (not $used) {
                        tag 'wildcard-matches-nothing-in-dep5-copyright',
                          "$wildcard (paragraph at line $current_line)";
                    }
                }
            }

            check_incomplete_creative_commons_license($short_license,
                $license, $current_line);
            if (defined($short_license) and $short_license =~ /\s++\|\s++/) {
                tag 'pipe-symbol-used-as-license-disjunction', $short_license,
                  "(paragraph at line $current_line)";
            }
            if ($found_license) {
                for (@short_licenses) {
                    $short_licenses_seen{$_} = $i;
                    if (not defined($full_license)) {
                        $required_standalone_licenses{$_} = $i;
                    } else {
                        if(defined($full_licenses_seen{$_})
                            and $_ ne 'public-domain') {
                            tag 'dep5-copyright-license-name-not-unique',
                              $_, "(paragraph at line $current_line)";
                        } else {
                            $full_licenses_seen{$_} = $current_line;
                        }
                    }
                }
            }else {
                tag 'missing-field-in-dep5-copyright', 'license',
                  "(paragraph at line $current_line)";
            }

            if (not defined $copyright) {
                tag 'missing-field-in-dep5-copyright', 'copyright',
                  "(paragraph at line $current_line)";
            }elsif ($copyright =~ m/\A\s*\Z/mxs) {
                tag 'missing-field-in-dep5-copyright', 'copyright',
                  '(empty field,',
                  "paragraph at line $current_line)";
            }

        }else {
            tag 'unknown-paragraph-in-dep5-copyright', 'paragraph at line',
              $current_line;
        }
    }
    if (@commas_in_files and not $commas_in_files) {
        my ($paragraph_no, $field_name) = @commas_in_files;
        tag 'comma-separated-files-in-dep5-copyright',
          'paragraph at line',
          $lines[$paragraph_no]{$field_name};
    } else {
        foreach my $srcfile (sort keys %file_licenses) {
            next if $srcfile =~ '^\.pc/';
            next unless $srcfile =~ /\.xml$/;
            my $file = $info->index_resolved_path($srcfile);
            my $seen = eval {
                my $xml
                  = XMLin($file->fs_path, ForceArray => [], KeyAttr => []);
                lc($xml->{'metadata_license'} // '');
            };
            next unless $seen;
            my $wanted = $file_licenses{$srcfile};
            tag 'inconsistent-appstream-metadata-license', $srcfile,
              "($seen != $wanted)"
              unless $seen eq $wanted
              or $info->name eq 'lintian';
        }
        foreach my $srcfile (sort keys %file_coverage) {
            my $i = $file_coverage{$srcfile};
            next if $srcfile =~ '^\.pc/';
            delete $file_para_coverage{$i};
            if ($srcfile =~ m,(^|/)(COPYING[^/]*|LICENSE)$,) {
                # license files do not require their own entry in d/copyright.
                tag 'license-file-listed-in-debian-copyright', $srcfile
                  if $i;
            } else {
                tag 'file-without-copyright-information', $srcfile
                  unless $i;
            }
        }
        foreach my $i (sort keys %file_para_coverage) {
            tag 'unused-file-paragraph-in-dep5-copyright',
              "paragraph at line $i";
        }
    }
    while ((my $license, $i) = each %required_standalone_licenses) {
        if (not defined $standalone_licenses{$license}) {
            tag 'missing-license-paragraph-in-dep5-copyright', $license,
              "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
        } elsif ($standalone_licenses{$license} == -1) {
            tag 'dep5-file-paragraph-references-header-paragraph', $license,
              "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
        }

    }
    while ((my $license, $i) = each %standalone_licenses) {
        if (not defined $required_standalone_licenses{$license}) {
            tag 'unused-license-paragraph-in-dep5-copyright', $license,
              "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
        }
    }
  LICENSE:
    while ((my $license, $i) = each %short_licenses_seen) {
        if ($license =~ m,\s,) {
            if($license =~ m,[^ ]+ \s+ with \s+ (.*),x) {
                my $exceptiontext = $1;
                unless ($exceptiontext =~ m,[^ ]+ \s+ exception,x) {
                    tag 'bad-exception-format-in-dep5-copyright', $license,
                      "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
                }
            }else {
                tag 'space-in-std-shortname-in-dep5-copyright', $license,
                  "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
            }
        }
        foreach my $bad_short_license ($BAD_SHORT_LICENSES->all) {
            my $value = $BAD_SHORT_LICENSES->value($bad_short_license);
            my $regex = $value->{'regex'};
            if ($license =~ m/$regex/x) {
                tag $value->{'tag'}, $license,
                  "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
                next LICENSE;
            }
        }
    }
    return;
}

# parse a license block
sub parse_license {
    my ($license_block, $line) = @_;
    my ($full_license, $short_license);
    return 0 unless defined($license_block);
    if ($license_block =~ m/\n/) {
        ($short_license, $full_license) = split /\n/, $license_block, 2;
    }else {
        $short_license = $license_block;
    }
    $short_license =~ s/[(),]/ /g;
    if ($short_license =~ m/\A\s*\Z/) {
        tag 'empty-short-license-in-dep5-copyright',
          "(paragraph at line $line)";
        return 1, $full_license, '';
    }
    $short_license = lc($short_license);
    my @licenses
      =map { "\L$_" } (split(m/\s++(?:and|or)\s++/, $short_license));
    return 1, $full_license, $short_license, @licenses;
}

sub get_field {
    my ($para, $field, $line) = @_;
    if (exists $para->{$field}) {
        return $para->{$field} unless wantarray;
        return ($field, $para->{$field});
    }

    # Fall back to a "likely misspelling" of the field.
    foreach my $f (sort keys %$para) {
        if (distance($field, $f) < 3) {
            tag 'field-name-typo-in-dep5-copyright', $f, '->', $field,
              "(line $line->{$f})";
            return $para->{$f} unless wantarray;
            return ($f, $para->{$f});
        }
    }
    return;
}

sub dequote_backslashes {
    my ($string) = @_;
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
    } else {
        return ($string, undef);
    }
}

sub parse_wildcard {
    my ($regex_src) = @_;
    my ($error);
    $regex_src =~ s,^\./+,,;
    $regex_src =~ s,//+,/,g;
    if ($regex_src eq '*') {
        return ('', WC_TYPE_DECENDANTS, undef);
    }
    if (index($regex_src, '?') == -1) {
        my $star_index = index($regex_src, '*');
        my $bslash_index = index($regex_src, '\\');
        if ($star_index == -1) {
            # Regular file-match, dequote "\\" if any and stop here.
            if ($bslash_index > -1) {
                ($regex_src, $error) = dequote_backslashes($regex_src);
            }
            return ($regex_src, WC_TYPE_FILE, $error);
        }
        if (length($regex_src) - 1 == $star_index
            and substr($regex_src, -2) eq '/*') {
            # Files: some-dir/*
            $regex_src = substr($regex_src, 0, -1);
            if ($bslash_index > -1) {
                ($regex_src, $error) = dequote_backslashes($regex_src);
            }
            return ($regex_src, WC_TYPE_DECENDANTS, $error);
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

sub get_all_files {
    my ($info) = @_;
    return grep { $_->is_file } $info->sorted_index;
}

sub check_files_excluded {
    my ($info, $excluded) = @_;
    my @files = grep { $_->is_file } $info->sorted_orig_index;
    my @wildcards = split /[\n\t ]+/, $excluded;
    for my $wildcard (@wildcards) {
        $wildcard =~ s/^\s+|\s+$//g;
        if ($wildcard eq '') {
            next;
        }
        my ($wc_value, $wc_type, $wildcard_error)= parse_wildcard($wildcard);
        if (defined $wildcard_error) {
            tag 'invalid-escape-sequence-in-dep5-copyright', $wildcard_error;
            next;
        }
        if ($wc_type eq WC_TYPE_FILE) {
            # Also match "dir/filename" for "Files-Excluded: dir"
            $wc_value = qr/^${wc_value}(?:\/|$)/;
        }
        for my $srcfile (@files) {
            next if $srcfile =~ m/^(?:debian|\.pc)\//;
            tag 'source-includes-file-in-files-excluded', $srcfile
              if $srcfile =~ qr/^$wc_value/;
        }
    }

    return;
}

sub check_incomplete_creative_commons_license {
    my ($short_license, $license, $current_line) = @_;
    return unless $short_license and $license;

    my $num_lines = $license =~ tr/\n//;
    tag 'incomplete-creative-commons-license', $short_license,
      "(paragraph at line $current_line)"
      if $short_license =~ m,^cc-,
      and $num_lines > 0
      and $num_lines < 20;

    return;
}

sub binary {
    my ($pkg, undef, $info, $proc, $group) = @_;
    my $found = 0;
    my $linked = 0;
    my $path = "usr/share/doc/$pkg";

    if ($info->index("$path/copyright.gz")) {
        tag 'copyright-file-compressed';
        $found = 1;
    }

    if (my $index_info = $info->index("$path/copyright")) {
        $found = 1;
        if ($index_info->is_symlink) {
            tag 'copyright-file-is-symlink';
            $linked = 1;
            # Fall through here - coll/copyright-file protects us
            # from reading through an "evil" link.
        }
    }

    if (not $found) {
        my $index_info = $info->index($path);
        if (defined $index_info && $index_info->is_symlink) {
            my $link = $index_info->link;

            # check if this symlink references a directory elsewhere
            if ($link =~ m,^(?:\.\.)?/,) {
                tag 'usr-share-doc-symlink-points-outside-of-usr-share-doc',
                  $link;
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
            $link =~ s,/.*,,;
            if (not depends_on($info, $proc, $link)) {
                tag 'usr-share-doc-symlink-without-dependency', $link;
                return;
            }
            # Check if the link points to a package from the same source.
            check_cross_link($group, $link);
            return;
        }
    }

    if (not $found) {
        # #522827: special exception for perl for now
        tag 'no-copyright-file'
          unless $pkg eq 'perl';
        return;
    }

    my $dcopy = $info->lab_data_path('copyright');
    # check that copyright is UTF-8 encoded
    my $line = file_is_encoded_in_non_utf8($dcopy);
    if ($line) {
        tag 'debian-copyright-file-uses-obsolete-national-encoding',
          "at line $line";
    }

    # check contents of copyright file
    $_ = path($dcopy)->slurp;

    if (m,\r,) {
        tag 'copyright-has-crs';
    }

    my $wrong_directory_detected = 0;

    if (m{ (usr/share/common-licenses/ ( [^ \t]*? ) \.gz) }xsm) {
        my ($path, $license) = ($1, $2);
        if ($KNOWN_COMMON_LICENSES->known($license)) {
            tag 'copyright-refers-to-compressed-license', $path;
        }
    }

    # Avoid complaining about referring to a versionless license file
    # if the word "version" appears nowhere in the copyright file.
    # This won't catch all of our false positives for GPL references
    # that don't include a specific version number, but it will get
    # the obvious ones.
    if (m,(usr/share/common-licenses/(L?GPL|GFDL))([^-]),i) {
        my ($ref, $license, $separator) = ($1, $2, $3);
        if ($separator =~ /[\d\w]/) {
            tag 'copyright-refers-to-nonexistent-license-file',
              "$ref$separator";
        } elsif (m,\b(?:any|or)\s+later(?:\s+version)?\b,i
            || m,License: $license-[\d\.]+\+,i
            || m,as Perl itself,i
            || m,License-Alias:\s+Perl,
            || m,License:\s+Perl,) {
            tag 'copyright-refers-to-symlink-license', $ref;
        } else {
            tag 'copyright-refers-to-versionless-license-file', $ref
              if /\bversion\b/;
        }
    }

    # References to /usr/share/common-licenses/BSD are deprecated as of Policy
    # 3.8.5.
    if (m,/usr/share/common-licenses/BSD,) {
        tag 'copyright-refers-to-deprecated-bsd-license-file';
    }

    if (m,(usr/share/common-licences),) {
        tag 'copyright-refers-to-incorrect-directory', $1;
        $wrong_directory_detected = 1;
    }

    if (m,usr/share/doc/copyright,) {
        tag 'copyright-refers-to-old-directory';
        $wrong_directory_detected = 1;
    }

    if (m,usr/doc/copyright,) {
        tag 'copyright-refers-to-old-directory';
        $wrong_directory_detected = 1;
    }

    # Lame check for old FSF zip code.  Try to avoid false positives from other
    # Cambridge, MA addresses.
    if (m/(?:Free\s*Software\s*Foundation.*02139|02111-1307)/s) {
        tag 'old-fsf-address-in-copyright-file';
    }

    # Whether the package is covered by the GPL, used later for the
    # libssl check.
    my $gpl;

    if (
        length($_) > 12_000
        and (
            m/  \b \QGNU GENERAL PUBLIC LICENSE\E \s*
                    \QTERMS AND CONDITIONS FOR COPYING,\E \s*
                    \QDISTRIBUTION AND MODIFICATION\E\b/mx
            or (    m/\bGNU GENERAL PUBLIC LICENSE\s*Version 3/
                and m/\bTERMS AND CONDITIONS\s/))
    ) {
        tag 'copyright-file-contains-full-gpl-license';
        $gpl = 1;
    }

    if (    length($_) > 12_000
        and m/\bGNU Free Documentation License\s*Version 1\.2/
        and m/\b1\. APPLICABILITY AND DEFINITIONS/) {
        tag 'copyright-file-contains-full-gfdl-license';
    }

    if (    length($_) > 10_000
        and m/\bApache License\s+Version 2\.0,/
        and m/TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION/) {
        tag 'copyright-file-contains-full-apache-2-license';
    }

    # wtf?
    if ((m,common-licenses(/\S+),) && (!m,/usr/share/common-licenses/,)) {
        tag 'copyright-does-not-refer-to-common-license-file', $1;
    }

    # This check is a bit prone to false positives, since some other
    # licenses mention the GPL.  Also exclude any mention of the GPL
    # following what looks like mail header fields, since sometimes
    # e-mail discussions of licensing are included in the copyright
    # file but aren't referring to the license of the package.
    if (
        not(
               m,/usr/share/common-licenses,
            || m/Zope Public License/
            || m/LICENSE AGREEMENT FOR PYTHON 1.6.1/
            || m/LaTeX Project Public License/
            || m/(?:^From:.*^To:|^To:.*^From:).*(?:GNU General Public License|GPL)/ms
            || m/AFFERO GENERAL PUBLIC LICENSE/
            || m/GNU Free Documentation License[,\s]*Version 1\.1/
            || m/CeCILL FREE SOFTWARE LICENSE AGREEMENT/ #v2.0
            || m/FREE SOFTWARE LICENSING AGREEMENT CeCILL/ #v1.1
            || m/CNRI OPEN SOURCE GPL-COMPATIBLE LICENSE AGREEMENT/
            || m/compatible\s+with\s+(?:the\s+)?(?:GNU\s+)?GPL/
            || m/(?:GNU\s+)?GPL\W+compatible/
            || m/was\s+previously\s+(?:distributed\s+)?under\s+the\s+GNU/
            || m/means\s+either\s+the\s+GNU\s+General\s+Public\s+License/
            || $wrong_directory_detected
        )
    ) {
        if (
            check_names_texts(
                qr/\b(?:GFDL|gnu[-_]free[-_]documentation[-_]license)\b/i,
                qr/GNU Free Documentation License|(?-i:\bGFDL\b)/i
            )
        ) {
            tag 'copyright-should-refer-to-common-license-file-for-gfdl';
        }elsif (
            check_names_texts(
qr/\b(?:LGPL|gnu[-_](?:lesser|library)[-_]general[-_]public[-_]license)\b/i,
qr/GNU (?:Lesser|Library) General Public License|(?-i:\bLGPL\b)/i
            )
        ) {
            tag 'copyright-should-refer-to-common-license-file-for-lgpl';
        }elsif (
            check_names_texts(
                qr/\b(?:GPL|gnu[-_]general[-_]public[-_]license)\b/i,
                qr/GNU General Public License|(?-i:\bGPL\b)/i
            )
        ) {
            tag 'copyright-should-refer-to-common-license-file-for-gpl';
            $gpl = 1;
        }elsif (
            check_names_texts(
                qr/\bapache[-_]2/i,
                qr/\bApache License\s*,?\s*Version 2|\b(?-i:Apache)-2/i
            )
        ) {
            tag 'copyright-should-refer-to-common-license-file-for-apache-2';
        }
    }

    if (
        check_names_texts(
            qr/\b(?:perl|artistic)\b/,
            sub {
                /(?:under )?(?:the )?(?:same )?(?:terms )?as Perl itself\b/i
                  &&!m,usr/share/common-licenses/,;
            })
    ) {
        tag 'copyright-file-lacks-pointer-to-perl-license';
    }

    # Checks for various packaging helper boilerplate.

    if (
           m,\<fill in (?:http/)?ftp site\>,o
        or m,\<Must follow here\>,o
        or m,\<Put the license of the package here,o
        or m,\<put author[\'\(]s\)? name and email here\>,o
        or m,\<Copyright \(C\) YYYY Name OfAuthor\>,o
        or m,Upstream Author\(s\),o
        or m,\<years\>,o
        or m,\<special license\>,o
        or m,\<Put the license of the package here indented by 1 space\>,o
        or m,\Q<This follows the format of Description: lines\E \s*
             \Qin control file>\E,ox
        or m,\<Including paragraphs\>,o
        or m,\<likewise for another author\>,o
    ) {
        tag 'helper-templates-in-copyright';
    }

    if (m/This copyright info was automatically extracted/o) {
        tag 'copyright-contains-automatically-extracted-boilerplate';
    }

    if (m,url://,o) {
        tag 'copyright-has-url-from-dh_make-boilerplate';
    }

    if (   index($_, DH_MAKE_TODO_BOILERPLATE_1) != -1
        or index($_, DH_MAKE_TODO_BOILERPLATE_2) != -1) {
        tag 'copyright-contains-dh_make-todo-boilerplate';
    }

    if (m,The\s+Debian\s+packaging\s+is\s+\(C\)\s+\d+,io) {
        tag 'copyright-with-old-dh-make-debian-copyright';
    }

    # Other flaws in the copyright phrasing or contents.
    if ($found && !$linked) {
        tag 'copyright-without-copyright-notice'
          unless /(?:Copyright|Copr\.|\302\251)(?:.*|[\(C\):\s]+)\b\d{4}\b
               |\bpublic(?:\s+|-)domain\b/xi;
    }

    check_spelling($_, $group->info->spelling_exceptions,
        $SPELLING_ERROR_IN_COPYRIGHT, 0);

    # Now, check for linking against libssl if the package is covered
    # by the GPL.  (This check was requested by ftp-master.)  First,
    # see if the package is under the GPL alone and try to exclude
    # packages with a mix of GPL and LGPL or Artistic licensing or
    # with an exception or exemption.
    if ($gpl || m,/usr/share/common-licenses/GPL,) {
        unless (m,exception|exemption|/usr/share/common-licenses/(?!GPL)\S,){
            my @depends;
            if (my $field = $info->field('depends')) {
                @depends = split(/\s*,\s*/, $field);
            }
            if (my $field = $info->field('pre-depends')) {
                push(@depends, split(/\s*,\s*/, $field));
            }
            if (any { /^libssl[0-9.]+(?:\s|\z)/ && !/\|/ } @depends) {
                tag 'possible-gpl-code-linked-with-openssl';
            }
        }
    }

    return;
} # </run>

# -----------------------------------

# Returns true if the package whose information is in $info depends $package
# or if $package is essential.
sub depends_on {
    my ($info, $proc, $package) = @_;
    my ($strong, $arch);
    return 1 if $KNOWN_ESSENTIAL->known($package);
    $strong = $info->relation('strong');
    return 1 if $strong->implies($package);
    $arch = $proc->pkg_arch;
    return 1 if $arch ne 'all' and $strong->implies("${package}:${arch}");
    return 0;
}

# Checks cross pkg links for /usr/share/doc/$pkg links
sub check_cross_link {
    my ($group, $fpkg) = @_;
    my $src = $group->get_source_processable;
    if ($src) {
        # source package is available; check it's list of binary
        return if defined $src->info->binary_package_type($fpkg);
        tag 'usr-share-doc-symlink-to-foreign-package', $fpkg;
    } else {
        # The source package is not available, but the binary could
        # be present anyway;  If they are in the same group, they claim
        # to have the same source (and source version)
        foreach my $proc ($group->get_processables('binary')){
            return if($proc->pkg_name eq $fpkg);
        }
        # It was not, but since the source package was not present, we cannot
        # tell if it is foreign or not at this point.
        #<<< No perltidy - tag name too long
        tag 'cannot-check-whether-usr-share-doc-symlink-points-to-foreign-package';
        #>>>
    }
    return;
}

# Checks the name and text of every license in the file against given name and
# text check coderefs, if the file is in the new format, if the file is in the
# old format only runs the text coderef against the whole file.
sub check_names_texts {
    my ($name_check, $text_check) = @_;

    my $make_check = sub {
        my $action = $_[0];

        if ((ref($action) || '') eq 'Regexp') {
            return sub { ${$_[0]} =~ $action };
        }
        return sub {
            $_ = ${$_[0]};
            return $action->();
        };
    };
    $text_check = $make_check->($text_check);

    my $file = \$_;
    local $@;
    local $_;
    eval {
        foreach my $paragraph (read_dpkg_control($file)) {
            next unless exists $paragraph->{license};

            my ($license_name, $license_text)
              = $paragraph->{license} =~ /^\s*([^\r\n]+)\r?\n(.*)\z/s;

            next if ($license_text||'') =~ /^[\s\r\n]*\z/;

            die 'MATCH'
              if $license_name =~ $name_check
              && $text_check->(\$license_text);
        }
    };
    if ($@)
    { # match or parse error: copyright not in new format, just check text
        return 1 if $@ =~ /^MATCH/;

        return $text_check->($file);
    }

    return; # did not match anything
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

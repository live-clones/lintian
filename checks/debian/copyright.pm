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
use List::MoreUtils qw(any none);
use Path::Tiny;
use Unicode::UTF8 qw[valid_utf8 decode_utf8];
use XML::LibXML;

use Lintian::Data;
use Lintian::Deb822Parser qw(parse_dpkg_control_string);
use Lintian::Relation::Version qw(versions_compare);
use Lintian::Spelling qw(check_spelling);

use constant {
    WC_TYPE_REGEX => 'REGEX',
    WC_TYPE_FILE => 'FILE',
    WC_TYPE_DESCENDANTS => 'DESCENDANTS',
};

use constant EMPTY => q{};
use constant SPACE => q{ };

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $KNOWN_ESSENTIAL = Lintian::Data->new('fields/essential');
our $KNOWN_COMMON_LICENSES
  =  Lintian::Data->new('copyright-file/common-licenses');

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
      unless $debian_dir;

    my $file = $debian_dir->child('copyright');

    unless ($file) {

        # also look for <pkgname>.copyright for a single installable
        my @installables = $self->processable->binaries;
        if (scalar @installables == 1) {

            $file = $debian_dir->child($installables[0] . '.copyright');
            $self->tag('named-copyright-for-single-installable', $file->name)
              if $file;
        }

        unless ($file) {
            $self->tag('no-debian-copyright-in-source');
            return;
        }

    } elsif ($file->is_symlink) {
        $self->tag('debian-copyright-is-symlink');
    }

    unless ($file->is_valid_utf8) {

        $self->tag('debian-copyright-file-uses-obsolete-national-encoding');
        return;
    }

    my $contents = $file->decoded_utf8;

    $self->check_dep5_copyright($contents);
    $self->check_apache_notice_files($contents);

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
    my ($self, $contents) = @_;

    return
      unless $contents =~ m/apache[-\s]+2\./i;

    my @notice_files = grep {
              $_->basename =~ m/^NOTICE(\.txt)?$/
          and $_->is_open_ok
          and $_->bytes =~ m/apache/i
    } $self->processable->patched->sorted_list;
    return
      unless @notice_files;

    my @binaries = $self->group->get_processables('binary');
    return
      unless @binaries;

    foreach my $binary (@binaries) {

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
        join(' ', @notice_files));

    return;
}

sub check_dep5_copyright {
    my ($self, $contents) = @_;

    if ($contents =~ /^Files-Excluded:/m) {

        if ($contents
            =~ m{^Format:.*/doc/packaging-manuals/copyright-format/1.0/?$}m) {

            $self->tag('repackaged-source-not-advertised')
              unless $self->processable->repacked
              || $self->processable->native;

        } else {
            $self->tag('files-excluded-without-copyright-format-1.0');
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

        $self->tag('no-dep5-copyright');
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

    my (@dep5, @lines);

    # probably DEP 5 format; let's try more checks
    eval {@dep5 = parse_dpkg_control_string($contents, 0, \@lines);};
    if ($@) {
        chomp $@;
        $@ =~ s/^syntax error at //;
        $self->tag('syntax-error-in-dep5-copyright', $@);
        return;
    }

    return
      unless @dep5;

    $self->parse_dep5(\@dep5, \@lines);

    return;
}

sub parse_dep5 {
    my ($self, $dep5ref, $linesref) = @_;

    my @dep5       = @$dep5ref;
    my @lines      = @$linesref;
    my $first_para = shift @dep5;

    my %standalone_licenses;
    my %required_standalone_licenses;
    my %short_licenses_seen;
    my %full_licenses_seen;

    for my $name (keys %{$first_para}) {
        my $new_name = $dep5_renamed_fields{$name};
        $self->tag('obsolete-field-in-dep5-copyright',
            $name, $new_name, "(line $lines[0]{$name})")
          if length $new_name;
    }

    $self->check_files_excluded($first_para->{'Files-Excluded'} // '')
      unless $self->processable->native;

    $self->tag('copyright-excludes-files-in-native-package')
      if exists $first_para->{'Files-Excluded'} && $self->processable->native;

    $self->tag('missing-field-in-dep5-copyright',
        'Format',"(line $lines[0]{'Format'})")
      if none { defined $first_para->{$_} } qw(Format Format-Specification);

    $self->tag('missing-explanation-for-contrib-or-non-free-package')
      if ($self->processable->source_field('Section') // EMPTY)
      =~ m{^(contrib|non-free)(/.+)?$}
      and none { defined $first_para->{$_} } qw(Comment Disclaimer);

    $self->tag('missing-explanation-for-repacked-upstream-tarball')
      if $self->processable->repacked
      and none { defined $first_para->{$_} } qw(Comment Files-Excluded)
      and ($first_para->{'Source'} // '') =~ m{^https?://};

    my (undef, $full_license_field, undef,@short_licenses_field)
      = $self->parse_license($first_para->{'License'}, 1);

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

    my @allpaths;
    if($self->processable->native) {
        @allpaths = $self->processable->patched->sorted_list;
    } else {
        @allpaths = $self->processable->orig->sorted_list;
    }

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    push(@allpaths, $debian_dir->descendants)
      if $debian_dir;

    my @shippedfiles = sort map { $_->name } grep { $_->is_file } @allpaths;

    my @licensefiles= grep { m,(^|/)(COPYING[^/]*|LICENSE)$, } @shippedfiles;
    my @quiltfiles = grep { m,^\.pc/, } @shippedfiles;

    my (@commas_in_files, %file_para_coverage, %file_licenses);
    my %file_coverage = map { $_ => 0 } @shippedfiles;
    my $i = 0;
    my $current_line = 0;
    my $commas_in_files = any { /,/s } @allpaths;

    for my $para (@dep5) {
        $i++;
        $current_line = $lines[$i]{'START-OF-PARAGRAPH'};
        my $files = $para->{Files};
        my $license   = $para->{License};
        my $copyright = $para->{Copyright};

        if (    not defined $files
            and defined $license
            and defined $copyright){
            $self->tag(
                'ambiguous-paragraph-in-dep5-copyright',
                "paragraph at line $current_line"
            );

            # If it is the first paragraph, it might be an instance of
            # the (no-longer) optional "first Files-field".
            $files = '*' if $i == 1;
        }

        if (defined $license and not defined $files) {
            my (undef, $full_license, $short_license,@short_licenses)
              = $self->parse_license($license, $current_line);
            $self->check_incomplete_creative_commons_license($short_license,
                $license, $current_line);
            # Standalone license paragraph
            if (defined($short_license) and $short_license =~ /\s++\|\s++/) {
                $self->tag('pipe-symbol-used-as-license-disjunction',
                    $short_license,"(paragraph at line $current_line)");
            }
            if (not defined($full_license)) {
                $self->tag('missing-license-text-in-dep5-copyright',
                    $license,"(paragraph at line $current_line)");
            }else {
                for (@short_licenses) {
                    if(defined($full_licenses_seen{$_})
                        and $_ ne 'public-domain') {
                        $self->tag(
                            'dep5-copyright-license-name-not-unique',
                            "(paragraph at line $current_line)"
                        );
                    } else {
                        $standalone_licenses{$_} = $i;
                        $full_licenses_seen{$_} = $current_line;
                    }
                    $short_licenses_seen{$_} = $i;
                }
            }
        }elsif (defined $files) {
            if ($files =~ m/\A\s*\Z/mxs) {
                $self->tag(
                    'missing-field-in-dep5-copyright',
                    'Files',
                    '(empty field,',
                    "paragraph at line $current_line)"
                );
            }

            $self->tag(
                'global-files-wildcard-not-first-paragraph-in-dep5-copyright',
                "(paragraph at line $current_line)"
            ) if $files eq '*' and $i > 1;

            my @listedfiles = split(SPACE, $files);

            # license files do not require their own entries in d/copyright.
            my $lc = List::Compare->new(\@licensefiles, \@listedfiles);
            my @listedlicensefiles = $lc->get_intersection;

            $self->tag('license-file-listed-in-debian-copyright',$_)
              for @listedlicensefiles;

            # Files paragraph
            if (not @commas_in_files and $files =~ /,/) {
                @commas_in_files = ($i, 'Files');
            }

            my ($found_license, $full_license, $short_license, @short_licenses)
              = $self->parse_license($license, $current_line);

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
                        $self->tag('invalid-escape-sequence-in-dep5-copyright',
                            substr($wildcard_error, 0, 2)
                              . " (paragraph at line $current_line)");
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

                    } elsif ($wc_type eq WC_TYPE_DESCENDANTS) {
                        my @wlist;

                        if ($wc_value eq q{}) {
                            # Special-case => Files: *
                            push(@wlist, @shippedfiles);

                        } elsif ($wc_value =~ /^debian\//) {
                            my $dir
                              = $self->processable->patched->lookup($wc_value);
                            if ($dir) {
                                my @files
                                  = grep { $_->is_file }$dir->descendants;
                                push(@wlist, @files);
                            }

                        } else {
                            my $dir;
                            if ($self->processable->native) {
                                $dir= $self->processable->patched->lookup(
                                    $wc_value);
                            } else {
                                $dir = $self->processable->orig->lookup(
                                    $wc_value);
                            }
                            if ($dir) {
                                my @files
                                  = grep { $_->is_file }$dir->descendants;
                                push(@wlist, @files);
                            }
                        }

                        $used = 1
                          if @wlist;

                        for my $entry (@wlist) {
                            $file_coverage{$entry} = $current_line;
                            $file_licenses{$entry} = $short_license;
                        }

                    } else {
                        for my $srcfile (@shippedfiles) {
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
                        $self->tag(
                            'wildcard-matches-nothing-in-dep5-copyright',
                            "$wildcard (paragraph at line $current_line)"
                        );
                    }
                }
            }

            $self->check_incomplete_creative_commons_license($short_license,
                $license, $current_line);
            if (defined($short_license) and $short_license =~ /\s++\|\s++/) {
                $self->tag('pipe-symbol-used-as-license-disjunction',
                    $short_license,"(paragraph at line $current_line)");
            }
            if ($found_license) {
                for (@short_licenses) {
                    $short_licenses_seen{$_} = $i;
                    if (not defined($full_license)) {
                        $required_standalone_licenses{$_} = $i;
                    } else {
                        if(defined($full_licenses_seen{$_})
                            and $_ ne 'public-domain') {
                            $self->tag(
                                'dep5-copyright-license-name-not-unique',
                                $_, "(paragraph at line $current_line)");
                        } else {
                            $full_licenses_seen{$_} = $current_line;
                        }
                    }
                }
            }else {
                $self->tag('missing-field-in-dep5-copyright',
                    'License',"(paragraph at line $current_line)");
            }

            if (not defined $copyright) {
                $self->tag('missing-field-in-dep5-copyright',
                    'Copyright',"(paragraph at line $current_line)");
            }elsif ($copyright =~ m/\A\s*\Z/mxs) {
                $self->tag(
                    'missing-field-in-dep5-copyright',
                    'Copyright',
                    '(empty field,',
                    "paragraph at line $current_line)"
                );
            }

        }else {
            $self->tag(
                'unknown-paragraph-in-dep5-copyright',
                'paragraph at line',
                $current_line
            );
        }
    }
    if (@commas_in_files and not $commas_in_files) {
        my ($paragraph_no, $field_name) = @commas_in_files;
        $self->tag(
            'comma-separated-files-in-dep5-copyright',
            'paragraph at line',
            $lines[$paragraph_no]{$field_name});
    } else {
        foreach my $srcfile (sort keys %file_licenses) {
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

            my $wanted = $file_licenses{$srcfile};
            $self->tag('inconsistent-appstream-metadata-license',
                $srcfile,"($seen != $wanted)")
              unless $seen eq $wanted
              or $self->processable->name eq 'lintian';
        }

        my @no_license_needed = (@quiltfiles, @licensefiles);
        my $lc = List::Compare->new(\@shippedfiles, \@no_license_needed);
        my @license_needed = $lc->get_Lonly;

        my @files_not_covered = grep { !$file_coverage{$_} } @license_needed;

        $self->tag('file-without-copyright-information',$_)
          for @files_not_covered;

        delete $file_para_coverage{$file_coverage{$_}}for keys %file_coverage;

        $self->tag('unused-file-paragraph-in-dep5-copyright',
            "paragraph at line $_")
          for sort keys %file_para_coverage;
    }

    while ((my $license, $i) = each %required_standalone_licenses) {
        if (not defined $standalone_licenses{$license}) {
            $self->tag('missing-license-paragraph-in-dep5-copyright',
                $license,
                "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})");
        } elsif ($standalone_licenses{$license} == -1) {
            $self->tag('dep5-file-paragraph-references-header-paragraph',
                $license,
                "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})");
        }

    }
    while ((my $license, $i) = each %standalone_licenses) {
        if (not defined $required_standalone_licenses{$license}) {
            $self->tag('unused-license-paragraph-in-dep5-copyright',
                $license,
                "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})");
        }
    }
  LICENSE:
    while ((my $license, $i) = each %short_licenses_seen) {
        if ($license =~ m,\s,) {
            if($license =~ m,[^ ]+ \s+ with \s+ (.*),x) {
                my $exceptiontext = $1;
                unless ($exceptiontext =~ m,[^ ]+ \s+ exception,x) {
                    $self->tag(
                        'bad-exception-format-in-dep5-copyright',
                        $license,
                        "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})"
                    );
                }
            }else {
                $self->tag('space-in-std-shortname-in-dep5-copyright',
                    $license,
                    "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})");
            }
        }
        foreach my $bad_short_license ($BAD_SHORT_LICENSES->all) {
            my $value = $BAD_SHORT_LICENSES->value($bad_short_license);
            my $regex = $value->{'regex'};
            if ($license =~ m/$regex/x) {
                $self->tag($value->{'tag'}, $license,
                    "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})");
                next LICENSE;
            }
        }
    }
    return;
}

# parse a license block
sub parse_license {
    my ($self, $license_block, $line) = @_;

    return 0
      unless defined $license_block;

    my ($full_license, $short_license);
    if ($license_block =~ /\n/) {
        ($short_license, $full_license) = split(/\n/, $license_block, 2);

    } else {
        $short_license = $license_block;
    }

    if(defined $full_license) {
        $self->tag('tab-in-license-text',
            "debian/copyright (paragraph at line $line)")
          if $full_license =~ /\t/;
    }

    $short_license =~ s/[(),]/ /g;

    if ($short_license =~ m/\A\s*\Z/) {
        $self->tag('empty-short-license-in-dep5-copyright',
            "(paragraph at line $line)");

        return (1, $full_license, EMPTY);
    }

    $short_license = lc($short_license);

    my @licenses
      =map { "\L$_" } (split(m/\s++(?:and|or)\s++/, $short_license));

    return (1, $full_license, $short_license, @licenses);
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

    if ($regex_src eq '*') {
        return ('', WC_TYPE_DESCENDANTS, undef);
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

sub check_files_excluded {
    my ($self, $excluded) = @_;

    my @files = grep { $_->is_file } $self->processable->orig->sorted_list;

    my @wildcards = split(/[\n\t ]+/, $excluded);
    s/^\s+|\s+$//g for @wildcards;

    for my $wildcard (@wildcards) {

        next
          if $wildcard eq EMPTY;

        my ($wc_value, $wc_type, $wildcard_error)= parse_wildcard($wildcard);
        if (defined $wildcard_error) {
            $self->tag('invalid-escape-sequence-in-dep5-copyright',
                $wildcard_error);
            next;
        }

        if ($wc_type eq WC_TYPE_FILE) {
            # Also match "dir/filename" for "Files-Excluded: dir"
            $wc_value = qr/^${wc_value}(?:\/|$)/;
        }

        for my $srcfile (@files) {

            next
              if $srcfile =~ m/^(?:debian|\.pc)\//;

            $self->tag('source-includes-file-in-files-excluded', $srcfile)
              if $srcfile =~ qr/^$wc_value/;
        }
    }

    return;
}

sub check_incomplete_creative_commons_license {
    my ($self, $short_license, $license, $current_line) = @_;

    return
      unless $short_license && $license;

    my $num_lines = $license =~ tr/\n//;

    $self->tag('incomplete-creative-commons-license',
        $short_license,"(paragraph at line $current_line)")
      if $short_license =~ /^cc-/
      && $num_lines > 0
      && $num_lines < 20;

    return;
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

    # check that copyright is UTF-8 encoded
    my $bytes = path($dcopy)->slurp;
    unless (valid_utf8($bytes)) {

        $self->tag('debian-copyright-file-uses-obsolete-national-encoding');
        return;
    }

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

    if ($contents =~ m/This copyright info was automatically extracted/) {
        $self->tag('copyright-contains-automatically-extracted-boilerplate');
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
          = split(/\s*,\s*/, $self->processable->field('Depends') // EMPTY);
        my @predepends
          = split(/\s*,\s*/,$self->processable->field('Pre-Depends') // EMPTY);

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
          if defined $source->binary_package_type($foreign);

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

# source-copyright-file -- lintian check script -*- perl -*-

# Copyright (C) 2011 Jakub Wilk
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

package Lintian::source_copyright;

use strict;
use warnings;
use autodie;

use List::MoreUtils qw(any);
use Text::Levenshtein qw(distance);

use Lintian::Relation::Version qw(versions_compare);
use Lintian::Tags qw(tag);
use Lintian::Util qw(parse_dpkg_control slurp_entire_file);

my $dep5_last_normative_change = '0+svn~166';
my $dep5_last_overhaul         = '0+svn~148';
my %dep5_renamed_fields        = (
    'format-specification' => 'format',
    'maintainer'           => 'upstream-contact',
    'upstream-maintainer'  => 'upstream-contact',
    'contact'              => 'upstream-contact',
    'name'                 => 'upstream-name',
);

sub run {
    my (undef, undef, $info) = @_;
    my $copyright_filename = $info->debfiles('copyright');

    if (-l $copyright_filename) {
        tag 'debian-copyright-is-symlink';
        return;
    }

    if (not -f $copyright_filename) {
        my @pkgs = $info->binaries;
        tag 'no-debian-copyright';
        $copyright_filename = undef;
        if (scalar @pkgs == 1) {

            # If debian/copyright doesn't exist, and the only a single
            # binary package is built, there's a good chance that the
            # copyright file is available as
            # debian/<pkgname>.copyright.
            $copyright_filename = $info->debfiles($pkgs[0] . '.copyright');
            if (not -f $copyright_filename or -l $copyright_filename) {
                $copyright_filename = undef;
            }
        }
    }

    if(defined($copyright_filename)) {
        _check_dep5_copyright($info,$copyright_filename);
    }
    return;
}

sub _check_dep5_copyright {
    my ($info,$copyright_filename) = @_;
    my $contents = slurp_entire_file($copyright_filename);
    my (@dep5, @lines);

    if (
        $contents !~ m{
               (^ | \n)
               (?i: format(:|[-\s]spec) )
               (?: . | \n\s+ )*
               (?: /dep[5s]?\b | \bDEP-?5\b
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
      if defined $uri;   # strip fragment identifier

    if (!defined $uri) {
        tag 'unknown-copyright-format-uri';
        return;
    }
        # Note that we allow people to use "https://" even the
        # policy says it must be "http://".  It might be
        # pedantically wrong, but it is not worth arguing over On
        # the plus side, it gives security to people blindly
        # copy-wasting the URLs using "https://".
        my $original_uri = $uri;
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
        }elsif ($uri =~ m,^https?://dep\.debian\.net/deps/dep5/?$,) {
            $version = '0+svn';
        }elsif (
            $uri =~ s{\A https?://svn\.debian\.org/
                                  wsvn/dep/web/deps/dep5\.mdwn\b}{}xsm
          ){
            $version = '0+svn';
            $uri =~ m,^\?(?:\S+[&;])?rev=(\d+)(?:[&;]\S+)?$,
              and $version = "$version~$1";
        }elsif (
            $uri =~ s{ \A https?://(?:svn|anonscm)\.debian\.org/
                                    viewvc/dep/web/deps/dep5\.mdwn\b}{}xsm
          ){
            $version = '0+svn';
            $uri =~ m{\A \? (?:\S+[&;])?
                             (?:pathrev|revision|rev)=(\d+)(?:[&;]\S+)?
                          \Z}xsm
              and $version = "$version~$1";
        }elsif (
            $uri =~ m{ \A
                       https?://www\.debian\.org/doc/
                       (?:packaging-manuals/)?copyright-format/(\d+\.\d+)/?
                   \Z}xsm
          ){
            $version = $1;
        }else {
            tag 'unknown-copyright-format-uri', $original_uri;
            return;
        }

        if (defined $version) {
            if ($version =~ m,wiki,) {
                tag 'wiki-copyright-format-uri', $original_uri;
            }elsif ($version =~ m,svn$,) {
                tag 'unversioned-copyright-format-uri', $original_uri;
            }elsif (versions_compare $version,
                '<<', $dep5_last_normative_change){
                tag 'out-of-date-copyright-format-uri', $original_uri;
            }
            if (versions_compare $version, '>=', $dep5_last_overhaul) {

                # We are reasonably certain that we're dealing
                # with an up-to-date DEP-5 format. Let's try to do
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
            }else {
                return;
            }
        }

    if (@dep5) {
        _parse_dep5($info,\@dep5,\@lines);
    } else {
        tag 'no-dep5-copyright';
    }
}

sub _parse_dep5 {
    my ($info,$dep5ref,$linesref) = @_;
    my @dep5 = @$dep5ref;
    my @lines = @$linesref;
    my $first_para = shift @dep5;
    my %standalone_licenses;
    my %required_standalone_licenses;
    for my $field (keys %{$first_para}) {
        my $renamed_to = $dep5_renamed_fields{$field};
        if (defined $renamed_to) {
            tag 'obsolete-field-in-dep5-copyright', $field,
              $renamed_to, "(line $lines[0]{$field})";
        }
    }
    if (    not defined $first_para->{'format'}
        and not defined $first_para->{'format-specification'}){
        tag 'missing-field-in-dep5-copyright', 'format',
          "(line $lines[0]{'format'})";
    }
    for my $license (split_licenses($first_para->{'license'})) {
        $required_standalone_licenses{$license} = 1;
    }
    my @commas_in_files;
    my $i = 0;
    for my $para (@dep5) {
        $i++;
        my ($files_fname, $files)
          =get_field($para, 'files', $lines[$i]);
        my $license   = get_field($para, 'license',   $lines[$i]);
        my $copyright = get_field($para, 'copyright', $lines[$i]);

        if (    not defined $files
            and defined $license
            and defined $copyright){
            tag 'ambiguous-paragraph-in-dep5-copyright',
              "paragraph at line $lines[$i]{'START-OF-PARAGRAPH'}";

            # If it is the first paragraph, it might be an instance of
            # the (no-longer) optional "first Files-field".
            $files = '*' if $i == 1;
        }

        if (defined $license and not defined $files) {

            # Standalone license paragraph
            if (not $license =~ m/\n/) {
                tag 'missing-license-text-in-dep5-copyright', lc $license,
                  "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
            }
            ($license, undef) = split /\n/, $license, 2;
            for (split_licenses($license)) {
                $standalone_licenses{$_} = $i;
            }
        }elsif (defined $files) {

            # Files paragraph
            if (not @commas_in_files and $files =~ /,/) {
                @commas_in_files = ($i, $files_fname);
            }
            if (defined $license) {
                for (split_licenses($license)) {
                    $required_standalone_licenses{$_} = $i;
                }
            }else {
                tag 'missing-field-in-dep5-copyright', 'license',
                  "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
            }
            if (not defined $copyright) {
                tag 'missing-field-in-dep5-copyright', 'copyright',
                  "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
            }
        }else {
            tag 'unknown-paragraph-in-dep5-copyright', 'paragraph at line',
              $lines[$i]{'START-OF-PARAGRAPH'};
        }
    }
    if (@commas_in_files) {
        my ($paragraph_no, $field_name) = @commas_in_files;
        if (not any { m/,/xsm } $info->sorted_index) {
            tag 'comma-separated-files-in-dep5-copyright',
              'paragraph at line',
              $lines[$paragraph_no]{$field_name};
        }
    }
    while ((my $license, $i) = each %required_standalone_licenses) {
        if (not defined $standalone_licenses{$license}) {
            tag 'missing-license-paragraph-in-dep5-copyright', $license,
              "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
        }
    }
    while ((my $license, $i) = each %standalone_licenses) {
        if (not defined $required_standalone_licenses{$license}) {
            tag 'unused-license-paragraph-in-dep5-copyright', $license,
              "(paragraph at line $lines[$i]{'START-OF-PARAGRAPH'})";
        }
    }
    return;
}

sub split_licenses {
    my ($license) = @_;
    return () unless defined($license);
    return () if $license =~ /\n/;
    $license =~ s/[(),]//;
    return map { "\L$_" } (split(m/\s++(?:and|or)\s++/, $license));
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

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

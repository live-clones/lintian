# debian/shlibs -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Debian::Shlibs;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::Compare;
use List::SomeUtils qw(any none uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $EQUALS => q{=};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

my @known_meta_labels = qw{
  Build-Depends-Package
  Build-Depends-Packages
  Ignore-Blacklist-Groups
};

has soname_by_filename => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %soname_by_filename;
        for my $item (@{$self->processable->installed->sorted_list}) {

            $soname_by_filename{$item->name}= $item->elf->{SONAME}[0]
              if exists $item->elf->{SONAME};
        }

        return \%soname_by_filename;
    });

has shlibs_positions_by_pretty_soname => (is => 'rw', default => sub { {} });
has symbols_positions_by_soname => (is => 'rw', default => sub { {} });

sub installable {
    my ($self) = @_;

    $self->check_shlibs_file;
    $self->check_symbols_file;

    my @pretty_sonames_from_shlibs
      = keys %{$self->shlibs_positions_by_pretty_soname};
    my @pretty_sonames_from_symbols
      = map { human_soname($_) } keys %{$self->symbols_positions_by_soname};

    # Compare the contents of the shlibs and symbols control files, but exclude
    # from this check shared libraries whose SONAMEs has no version.  Those can
    # only be represented in symbols files and aren't expected in shlibs files.
    my $extra_lc = List::Compare->new(\@pretty_sonames_from_symbols,
        \@pretty_sonames_from_shlibs);

    if (%{$self->shlibs_positions_by_pretty_soname}) {

        my @versioned = grep { m{ } } $extra_lc->get_Lonly;

        $self->hint('symbols-for-undeclared-shared-library', $_)for @versioned;
    }

    return;
}

sub check_shlibs_file {
    my ($self) = @_;

    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};

    # Libraries with no version information can't be represented by
    # the shlibs format (but can be represented by symbols).  We want
    # to warn about them if they appear in public directories.  If
    # they're in private directories, assume they're plugins or
    # private libraries and are safe.
    my @unversioned_libraries;
    for my $file_name (keys %{$self->soname_by_filename}) {

        my $pretty_soname
          = human_soname($self->soname_by_filename->{$file_name});
        next
          if $pretty_soname =~ m{ };

        push(@unversioned_libraries, $file_name);
        $self->hint('shared-library-lacks-version', $file_name, $pretty_soname)
          if any { (dirname($file_name) . $SLASH) eq $_ } @ldconfig_folders;
    }

    my $versioned_lc = List::Compare->new([keys %{$self->soname_by_filename}],
        \@unversioned_libraries);
    my @versioned_libraries = $versioned_lc->get_Lonly;

    # 4th step: check shlibs control file
    # $package_version may be undef in very broken packages
    my $shlibs_file = $self->processable->control->lookup('shlibs');
    $shlibs_file = undef
      if defined $shlibs_file && !$shlibs_file->is_file;

    # no shared libraries included in package, thus shlibs control
    # file should not be present
    $self->hint('empty-shlibs')
      if defined $shlibs_file && !@versioned_libraries;

    # shared libraries included, thus shlibs control file has to exist
    for my $file_name (@versioned_libraries) {

        # only public shared libraries
        $self->hint('no-shlibs', $file_name)
          if (any { (dirname($file_name) . $SLASH) eq $_ } @ldconfig_folders)
          && !defined $shlibs_file
          && $self->processable->type ne 'udeb'
          && !is_nss_plugin($file_name);
    }

    if (@versioned_libraries && defined $shlibs_file) {

        my @shlibs_prerequisites;

        my @lines = split(/\n/, $shlibs_file->decoded_utf8);

        my $position = 1;
        for my $line (@lines) {

            next
              if $line =~ m{^ \s* $}x
              || $line =~ m{^ [#] }x;

            # We exclude udebs from the checks for correct shared library
            # dependencies, since packages may contain dependencies on
            # other udeb packages.

            my $udeb = $EMPTY;
            $udeb = 'udeb: '
              if $line =~ s/^udeb:\s+//;

            my ($name, $version, @prerequisites) = split($SPACE, $line);
            my $pretty_soname = "$udeb$name $version";

            $self->shlibs_positions_by_pretty_soname->{$pretty_soname} //= [];
            push(
                @{$self->shlibs_positions_by_pretty_soname->{$pretty_soname}},
                $position
            );

            push(@shlibs_prerequisites, join($SPACE, @prerequisites))
              unless $udeb;

        } continue {
            ++$position;
        }

        my @duplicate_pretty_sonames
          = grep { @{$self->shlibs_positions_by_pretty_soname->{$_}} > 1 }
          keys %{$self->shlibs_positions_by_pretty_soname};

        for my $pretty_soname (@duplicate_pretty_sonames) {

            my $indicator
              = $LEFT_PARENTHESIS . 'lines'
              . $SPACE
              . join($SPACE,
                sort { $a <=> $b }
                  @{$self->shlibs_positions_by_pretty_soname->{$pretty_soname}}
              ). $RIGHT_PARENTHESIS;

            $self->hint('duplicate-in-shlibs', $indicator,$pretty_soname);
        }

        my @used_pretty_sonames;
        for my $file_name (@versioned_libraries) {

            my $pretty_soname
              = human_soname($self->soname_by_filename->{$file_name});

            push(@used_pretty_sonames, $pretty_soname);
            push(@used_pretty_sonames, "udeb: $pretty_soname");

            # only public shared libraries
            $self->hint('ships-undeclared-shared-library',
                $pretty_soname, 'for', $file_name)
              if (
                any { (dirname($file_name) . $SLASH) eq $_ }
                @ldconfig_folders
              )
              && !@{$self->shlibs_positions_by_pretty_soname->{$pretty_soname}
                  // []}
              && !is_nss_plugin($file_name);
        }

        my $unused_lc
          = List::Compare->new(
            [keys %{$self->shlibs_positions_by_pretty_soname}],
            \@used_pretty_sonames);

        $self->hint('shared-library-not-shipped', $_)for $unused_lc->get_Lonly;

        my $fields = $self->processable->fields;

        # Check that all of the packages listed as dependencies in
        # the shlibs file are satisfied by the current package or
        # its Provides.  Normally, packages should only declare
        # dependencies in their shlibs that they themselves can
        # satisfy.
        my $provides = $self->processable->name;
        $provides
          .= $LEFT_PARENTHESIS
          . $EQUALS
          . $SPACE
          . $fields->value('Version')
          . $RIGHT_PARENTHESIS
          if $fields->declares('Version');

        $provides
          = $self->processable->relation('Provides')->logical_and($provides);

        for my $prerequisite (uniq @shlibs_prerequisites) {

            $self->hint('distant-prerequisite-in-shlibs', $prerequisite)
              unless $provides->satisfies($prerequisite);

            $self->hint('outdated-relation-in-shlibs', $prerequisite)
              if $prerequisite =~ m/\(\s*[><](?![<>=])\s*/;
        }
    }

    return;
}

sub check_symbols_file {
    my ($self) = @_;

    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};
    my @shared_libraries = keys %{$self->soname_by_filename};

    my $fields = $self->processable->fields;
    my $symbols_file = $self->processable->control->lookup('symbols');

    if (!defined $symbols_file
        && $self->processable->type ne 'udeb') {

        for my $file_name (@shared_libraries){

            my $item = $self->processable->installed->lookup($file_name);
            next
              unless defined $item;

            my @symbols
              = grep { $_->section eq '.text' || $_->section eq 'UND' }
              @{$item->elf->{SYMBOLS} // []};

            # only public shared libraries
            # Skip Objective C libraries as instance/class methods do not
            # appear in the symbol table
            $self->hint('no-symbols-control-file', $file_name)
              if (
                any { (dirname($file_name) . $SLASH) eq $_ }
                @ldconfig_folders
              )
              && (none { $_->name =~ m/^__objc_/ } @symbols)
              && !is_nss_plugin($file_name);
        }
    }

    return
      unless defined $symbols_file;

    # no shared libraries included in package, thus symbols
    # control file should not be present
    $self->hint('empty-shared-library-symbols')
      unless @shared_libraries;

    # Assume the version to be a non-native version to avoid
    # uninitialization warnings later.
    my $package_version = $fields->value('Version') || '0-1';

    my $package_version_wo_rev = $package_version;
    $package_version_wo_rev =~ s/^ (.+) - [^-]+ $/$1/x;

    my @sonames;
    my %symbols_by_soname;
    my %full_version_symbols_by_soname;
    my %debian_revision_symbols_by_soname;
    my %prerequisites_by_soname;
    my %positions_by_soname_and_meta_label;
    my @syntax_errors;
    my $template_count = 0;

    my @lines = split(/\n/, $symbols_file->decoded_utf8);

    my $current_soname = $EMPTY;
    my $position = 1;
    for my $line (@lines) {

        next
          if $line =~ m{^ \s* $}x
          || $line =~ m{^ [#] }x;

        # soname, main dependency template
        if ($line
            =~ m{^ ([^\s|*]\S+) \s\S+\s* (?: [(] \S+\s+\S+ [)] | [#]MINVER[#] )? }x
        ){

            $current_soname = $1;
            push(@sonames, $current_soname);

            $line =~ s/^\Q$current_soname\E\s*//;

            $self->symbols_positions_by_soname->{$current_soname} //= [];
            push(
                @{$self->symbols_positions_by_soname->{$current_soname}},
                $position
            );

            for my $conjunctive (split(m{ \s* , \s* }x, $line)) {
                for my $disjunctive (split(m{ \s* [|] \s* }x, $conjunctive)){

                    $disjunctive
                      =~ m{^ (\S+) ( \s* (?: [(] \S+\s+\S+ [)] | [#]MINVER[#]))? $}x;

                    my $package = $1;
                    my $version = $2 || $EMPTY;

                    if (length $package) {
                        $prerequisites_by_soname{$current_soname} //= [];
                        push(
                            @{$prerequisites_by_soname{$current_soname}},
                            $package . $version
                        );

                    } else {
                        push(@syntax_errors, $position);
                    }
                }
            }

            $template_count = 0;

            next;
        }

        # alternative dependency template
        if ($line
            =~ m{^ [|] \s+\S+\s* (?: [(] \S+\s+\S+ [)] | [#]MINVER[#] )? }x) {

            my $error = 0;

            if (%{$positions_by_soname_and_meta_label{$current_soname} // {} }
                || !length $current_soname) {

                push(@syntax_errors, $position);
                $error = 1;
            }

            $line =~ s{^ [|] \s* }{}x;

            for my $conjunctive (split(m{ \s* , \s* }x, $line)) {
                for my $disjunctive (split(m{ \s* [|] \s* }x, $conjunctive)) {

                    $disjunctive
                      =~ m{^ (\S+) ( \s* (?: [(] \S+ \s+ \S+ [)] | [#]MINVER[#] ) )? $}x;

                    my $package = $1;
                    my $version = $2 || $EMPTY;

                    if (length $package) {
                        $prerequisites_by_soname{$current_soname} //= [];
                        push(
                            @{$prerequisites_by_soname{$current_soname}},
                            $package . $version
                        );

                    } else {
                        push(@syntax_errors, $position)
                          unless $error;

                        $error = 1;
                    }
                }
            }

            $template_count++ unless $error;

            next;
        }

        # meta-information
        if ($line =~ m{^ [*] \s (\S+) : \s \S+ }x) {

            my $meta_label = $1;

            $positions_by_soname_and_meta_label{$current_soname}{$meta_label}
              //= [];
            push(
                @{
                    $positions_by_soname_and_meta_label{$current_soname}
                      {$meta_label}
                },
                $position
            );

            push(@syntax_errors, $position)
              if !defined $current_soname
              || @{$symbols_by_soname{$current_soname} // [] };

            next;
        }

        # Symbol definition
        if ($line =~ m{^\s+ (\S+) \s (\S+) (?:\s (\S+ (?:\s\S+)? ) )? $}x) {

            my $symbol = $1;
            my $version = $2;
            my $selector = $3 // $EMPTY;

            push(@syntax_errors, $position)
              unless length $current_soname;

            $symbols_by_soname{$current_soname} //= [];
            push(@{$symbols_by_soname{$current_soname}}, $symbol);

            if ($version eq $package_version && $package_version =~ m{-}) {
                $full_version_symbols_by_soname{$current_soname} //= [];
                push(
                    @{$full_version_symbols_by_soname{$current_soname}},
                    $symbol
                );

            } elsif ($version =~ m{-}
                && $version !~ m{~$}
                && $version ne $package_version_wo_rev) {

                $debian_revision_symbols_by_soname{$current_soname} //= [];
                push(
                    @{$debian_revision_symbols_by_soname{$current_soname}},
                    $symbol
                );
            }

            $self->hint('invalid-template-id-in-symbols-file',
                $selector, "(line $position)")
              if length $selector
              && ($selector !~ m{^ \d+ $}x || $selector > $template_count);

            next;
        }

        push(@syntax_errors, $position);

    } continue {
        ++$position;
    }

    my @duplicate_sonames
      = grep { @{$self->symbols_positions_by_soname->{$_}} > 1 }
      keys %{$self->symbols_positions_by_soname};

    for my $soname (@duplicate_sonames) {

        my $indicator
          = $LEFT_PARENTHESIS . 'lines'
          . $SPACE
          . join($SPACE,
            sort { $a <=> $b }@{$self->symbols_positions_by_soname->{$soname}})
          . $RIGHT_PARENTHESIS;

        my $pretty_soname = human_soname($soname);

        $self->hint('duplicate-entry-in-symbols-control-file',
            $indicator,$pretty_soname);
    }

    $self->hint('syntax-error-in-symbols-file',"(line $_)")
      for uniq @syntax_errors;

    # Check that all of the packages listed as dependencies in the symbols
    # file are satisfied by the current package or its Provides.
    # Normally, packages should only declare dependencies in their symbols
    # files that they themselves can satisfy.
    my $provides = $self->processable->name;
    $provides
      .= $LEFT_PARENTHESIS
      . $EQUALS
      . $SPACE
      . $fields->value('Version')
      . $RIGHT_PARENTHESIS
      if $fields->declares('Version');

    $provides
      = $self->processable->relation('Provides')->logical_and($provides);

    for my $soname (uniq @sonames) {

        my @used_meta_labels
          = keys %{$positions_by_soname_and_meta_label{$soname} // {} };

        my $meta_lc
          = List::Compare->new(\@used_meta_labels, \@known_meta_labels);

        for my $meta_label ($meta_lc->get_Lonly) {

            $self->hint('unknown-meta-field-in-symbols-file',
                $meta_label, "($soname, line $_)")
              for @{$positions_by_soname_and_meta_label{$soname}{$meta_label}};
        }

        $self->hint('symbols-file-missing-build-depends-package-field',$soname)
          if none { $_ eq 'Build-Depends-Package' } @used_meta_labels;

        my @full_version_symbols
          = @{$full_version_symbols_by_soname{$soname} // [] };
        if (@full_version_symbols) {

            my @sorted = sort +uniq @full_version_symbols;

            my $context = 'on symbol ' . $sorted[0];
            $context .= ' and ' . (scalar @sorted - 1) . ' others'
              if @sorted > 1;

            $self->hint(
                'symbols-file-contains-current-version-with-debian-revision',
                $context, "($soname)");
        }

        my @debian_revision_symbols
          = @{$debian_revision_symbols_by_soname{$soname} // [] };
        if (@debian_revision_symbols) {

            my @sorted = sort +uniq @debian_revision_symbols;

            my $context = 'on symbol ' . $sorted[0];
            $context .= ' and ' . (scalar @sorted - 1) . ' others'
              if @sorted > 1;

            $self->hint('symbols-file-contains-debian-revision',
                $context, "($soname)");
        }

        # Deduplicate the list of dependencies before warning so that we don't
        # duplicate warnings.
        for
          my $prerequisite (uniq @{$prerequisites_by_soname{$soname} // [] }) {

            $prerequisite =~ s/ [ ] [#] MINVER [#] $//x;
            $self->hint('symbols-declares-dependency-on-other-package',
                $prerequisite, "($soname)")
              unless $provides->satisfies($prerequisite);
        }
    }

    my @used_pretty_sonames;
    for my $filename (@shared_libraries) {

        my $soname = $self->soname_by_filename->{$filename};
        my $pretty_soname = human_soname($soname);

        push(@used_pretty_sonames, $pretty_soname);
        push(@used_pretty_sonames, "udeb: $pretty_soname");

        # only public shared libraries
        $self->hint('shared-library-symbols-not-tracked',
            $pretty_soname,'for', $filename)
          if (
            any { (dirname($filename) . $SLASH) eq $_ }
            @ldconfig_folders
          )
          && !@{$self->symbols_positions_by_soname->{$soname}// [] }
          && !is_nss_plugin($filename);
    }

    my @available_pretty_sonames
      = map { human_soname($_) } keys %{$self->symbols_positions_by_soname};

    my $unused_lc
      = List::Compare->new(\@available_pretty_sonames,\@used_pretty_sonames);

    $self->hint('surplus-shared-library-symbols', $_)for $unused_lc->get_Lonly;

    return;
}

# Extract the library name and the version from an SONAME and return them
# separated by a space.  This code should match the split_soname function in
# dpkg-shlibdeps.
sub human_soname {
    my ($string) = @_;

    # libfoo.so.X.X
    # libfoo-X.X.so
    if (   $string =~ m{^ (.*) [.]so[.] (.*) $}x
        || $string =~ m{^ (.*) - (\d.*) [.]so $}x) {

        my $name = $1;
        my $version = $2;

        return $name . $SPACE . $version;
    }

    return $string;
}

# Returns a truth value if the first argument appears to be the path
# to a libc nss plugin (libnss_<name>.so.$version).
sub is_nss_plugin {
    my ($name) = @_;

    return 1
      if $name =~ m{^ (?:.*/)? libnss_[^.]+ [.]so[.] \d+ $}x;

    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

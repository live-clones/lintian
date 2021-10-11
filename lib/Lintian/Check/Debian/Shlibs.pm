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

has soname_by_file => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $objdump = $self->processable->objdump_info;

        my %soname_by_file;
        for my $name (keys %{$objdump}) {

            $soname_by_file{$name} = $objdump->{$name}{SONAME}[0]
              if exists $objdump->{$name}{SONAME};
        }

        return \%soname_by_file;
    });

has shlibs_positions_by_pretty_soname => (is => 'rw', default => sub { {} });
has symbols_positions_by_pretty_soname => (is => 'rw', default => sub { {} });

sub installable {
    my ($self) = @_;

    $self->check_shlibs_file;
    $self->check_symbols_file;

    # Compare the contents of the shlibs and symbols control files, but exclude
    # from this check shared libraries whose SONAMEs has no version.  Those can
    # only be represented in symbols files and aren't expected in shlibs files.
    my $extra_lc = List::Compare->new(
        [keys %{$self->symbols_positions_by_pretty_soname}],
        [keys %{$self->shlibs_positions_by_pretty_soname}]);

    if (%{$self->shlibs_positions_by_pretty_soname}) {

        my @versioned = grep { / / } $extra_lc->get_Lonly;

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
    for my $name (keys %{$self->soname_by_file}) {

        my $pretty_soname = human_soname($self->soname_by_file->{$name});
        next
          if $pretty_soname =~ m{ };

        push(@unversioned_libraries, $name);
        $self->hint('shared-library-lacks-version', $name, $pretty_soname)
          if any { (dirname($name) . $SLASH) eq $_ } @ldconfig_folders;
    }

    my $versioned_lc = List::Compare->new([keys %{$self->soname_by_file}],
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
    for my $name (@versioned_libraries) {

        # only public shared libraries
        $self->hint('no-shlibs', $name)
          if (any { (dirname($name) . $SLASH) eq $_ } @ldconfig_folders)
          && !defined $shlibs_file
          && $self->processable->type ne 'udeb'
          && !is_nss_plugin($name);
    }

    if (@versioned_libraries && defined $shlibs_file) {

        my @shlibs_prerequisites;

        my @lines = split(/\n/, $shlibs_file->decoded_utf8);

        my $position = 1;
        for my $line (@lines) {

            next
              if $line =~ /^\s*$/
              || $line =~ /^#/;

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

        my @duplicates
          = grep { @{$self->shlibs_positions_by_pretty_soname->{$_}} > 1 }
          keys %{$self->shlibs_positions_by_pretty_soname};

        for my $pretty_soname (@duplicates) {

            my $indicator
              = $LEFT_PARENTHESIS . 'lines'
              . $SPACE
              . join($SPACE,
                sort { $a <=> $b }
                  @{$self->shlibs_positions_by_pretty_soname->{$pretty_soname}}
              ). $RIGHT_PARENTHESIS;

            $self->hint('duplicate-in-shlibs', $indicator,$pretty_soname);
        }

        my @used_sonames;
        for my $name (@versioned_libraries) {

            my $pretty_soname = human_soname($self->soname_by_file->{$name});

            push(@used_sonames, $pretty_soname);
            push(@used_sonames, "udeb: $pretty_soname");

            # only public shared libraries
            $self->hint('ships-undeclared-shared-library',
                $pretty_soname, 'for', $name)
              if (
                any { (dirname($name) . $SLASH) eq $_ }
                @ldconfig_folders
              )
              && !@{$self->shlibs_positions_by_pretty_soname->{$pretty_soname}
                  // []}
              && !is_nss_plugin($name);
        }

        my $unused_lc
          = List::Compare->new(
            [keys %{$self->shlibs_positions_by_pretty_soname}],
            \@used_sonames);

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
    my @shared_libraries = keys %{$self->soname_by_file};

    my $fields = $self->processable->fields;
    my $symbols_file = $self->processable->control->lookup('symbols');

    if (!defined $symbols_file
        && $self->processable->type ne 'udeb') {

        for my $name (@shared_libraries){

            my $objdump = $self->processable->objdump_info->{$name};

            # only public shared libraries
            # Skip Objective C libraries as instance/class methods do not
            # appear in the symbol table
            $self->hint('no-symbols-control-file', $name)
              if (any { (dirname($name) . $SLASH) eq $_ } @ldconfig_folders)
              && (none { @{$_}[2] =~ m/^__objc_/ } @{$objdump->{SYMBOLS}})
              && !is_nss_plugin($name);
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

    my @symbols;
    my @full_version_symbols;
    my @debian_revision_symbols;
    my @prerequisites;
    my @syntax_errors;
    my %positions_by_meta_label;
    my $template_count = 0;

    my @lines = split(/\n/, $symbols_file->decoded_utf8);

    my $soname = $EMPTY;
    my $position = 1;
    for my $line (@lines) {

        next
          if $line =~ /^\s*$/
          || $line =~ /^#/;

        # soname, main dependency template
        if ($line =~ /^([^\s|*]\S+)\s\S+\s*(?:\(\S+\s+\S+\)|\#MINVER\#)?/){

            $soname = $1;

            $line =~ s/^\Q$soname\E\s*//;
            my $pretty_soname = human_soname($soname);

            $self->symbols_positions_by_pretty_soname->{$pretty_soname} //= [];
            push(
                @{
                    $self->symbols_positions_by_pretty_soname->{$pretty_soname}
                },
                $position
            );

            for my $conjunctive (split(m{ \s* , \s* }x, $line)) {
                for my $disjunctive (split(m{ \s* [|] \s* }x, $conjunctive)){

                    $disjunctive
                      =~ m{^ (\S+) ( \s* (?: [(] \S+ \s+ \S+ [)] | [#]MINVER[#]))? $}x;

                    my $package = $1;
                    my $version = $2 || $EMPTY;

                    if (length $package) {
                        push(@prerequisites, $package . $version);

                    } else {
                        push(@syntax_errors, $position);
                    }
                }
            }

            $template_count = 0;
            @symbols = ();

            next;
        }

        # alternative dependency template
        if ($line =~ /^\|\s+\S+\s*(?:\(\S+\s+\S+\)|#MINVER#)?/) {

            my $error = 0;

            if (%positions_by_meta_label || !length $soname) {

                push(@syntax_errors, $position);
                $error = 1;
            }

            $line =~ s/^\|\s*//;

            for my $conjunctive (split(m{ \s* , \s* }x, $line)) {
                for my $disjunctive (split(m{ \s* [|] \s* }x, $conjunctive)) {

                    $disjunctive
                      =~ m{^ (\S+) ( \s* (?: [(] \S+ \s+ \S+ [)] | [#]MINVER[#] ) )? $}x;

                    my $package = $1;
                    my $version = $2 || $EMPTY;

                    if (length $package) {
                        push(@prerequisites, $package . $version);

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
        if ($line =~ /^\*\s(\S+):\s\S+/) {

            my $meta_label = $1;

            $positions_by_meta_label{$meta_label} //= [];
            push(@{$positions_by_meta_label{$meta_label}}, $position);

            push(@syntax_errors, $position)
              if !defined $soname || @symbols;

            next;
        }

        # Symbol definition
        if ($line =~ /^\s+(\S+)\s(\S+)(?:\s(\S+(?:\s\S+)?))?$/) {

            my $symbol = $1;
            my $version = $2;
            my $selector = $3 // $EMPTY;

            push(@syntax_errors, $position)
              unless length $soname;

            push(@symbols, $symbol);

            if ($version eq $package_version && $package_version =~ /-/) {
                push(@full_version_symbols, $symbol);

            } elsif ($version =~ /-/
                && $version !~ /~$/
                && $version ne $package_version_wo_rev) {

                push(@debian_revision_symbols, $symbol);
            }

            $self->hint('invalid-template-id-in-symbols-file',
                "(line $position)")
              if length $selector
              && ($selector !~ /^\d+$/ || $selector > $template_count);

            next;
        }

        push(@syntax_errors, $position);

    } continue {
        ++$position;
    }

    my @duplicates
      = grep { @{$self->symbols_positions_by_pretty_soname->{$_}} > 1 }
      keys %{$self->symbols_positions_by_pretty_soname};

    for my $pretty_soname (@duplicates) {

        my $indicator
          = $LEFT_PARENTHESIS . 'lines'
          . $SPACE
          . join($SPACE,
            sort { $a <=> $b }
              @{$self->symbols_positions_by_pretty_soname->{$pretty_soname}})
          . $RIGHT_PARENTHESIS;

        $self->hint('duplicate-entry-in-symbols-control-file',
            $indicator,$pretty_soname);
    }

    $self->hint('syntax-error-in-symbols-file',"(line $_)")
      for uniq @syntax_errors;

    my $meta_lc = List::Compare->new([keys %positions_by_meta_label],
        \@known_meta_labels);

    for my $meta_label ($meta_lc->get_Lonly) {

        $self->hint('unknown-meta-field-in-symbols-file',
            "(line $_)", $meta_label)
          for @{$positions_by_meta_label{$meta_label}};
    }

    if (@full_version_symbols) {

        my @sorted = sort +uniq @full_version_symbols;

        my $context = 'on symbol ' . $sorted[0];
        $context .= ' and ' . (scalar @sorted - 1) . ' others'
          if @sorted > 1;

        $self->hint(
            'symbols-file-contains-current-version-with-debian-revision',
            $context);
    }

    if (@debian_revision_symbols) {

        my @sorted = sort +uniq @debian_revision_symbols;

        my $context = 'on symbol ' . $sorted[0];
        $context .= ' and ' . (scalar @sorted - 1) . ' others'
          if @sorted > 1;

        $self->hint('symbols-file-contains-debian-revision', $context);
    }

    my @used_sonames;
    for my $name (@shared_libraries) {

        my $pretty_soname = human_soname($self->soname_by_file->{$name});
        push(@used_sonames, $pretty_soname);
        push(@used_sonames, "udeb: $pretty_soname");

        # only public shared libraries
        $self->hint('shared-library-symbols-not-tracked',
            $pretty_soname,'for', $name)
          if (
            any { (dirname($name) . $SLASH) eq $_ }
            @ldconfig_folders
          )
          && !@{$self->symbols_positions_by_pretty_soname->{$pretty_soname}
              // [] }
          && !is_nss_plugin($name);
    }

    my $unused_lc
      = List::Compare->new([keys %{$self->symbols_positions_by_pretty_soname}],
        \@used_sonames);

    $self->hint('surplus-shared-library-symbols', $_)for $unused_lc->get_Lonly;

    $self->hint('symbols-file-missing-build-depends-package-field')
      if none { $_ eq 'Build-Depends-Package' } keys %positions_by_meta_label;

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

    # Deduplicate the list of dependencies before warning so that we don't
    # duplicate warnings.

    for my $prerequisite (uniq @prerequisites) {

        $prerequisite =~ s/ [ ] [#] MINVER [#] $//x;
        $self->hint('symbols-declares-dependency-on-other-package',
            $prerequisite)
          unless $provides->satisfies($prerequisite);
    }

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

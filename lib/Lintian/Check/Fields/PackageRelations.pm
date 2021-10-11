# fields/package-relations -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2019-2020 Chris Lamb <lamby@debian.org>
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::Check::Fields::PackageRelations;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Dpkg::Version qw(version_check);
use List::SomeUtils qw(any);

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $EQUAL => q{=};
const my $VERTICAL_BAR => q{|};

# Still in the archive but shouldn't be the primary Emacs dependency.
my @obsolete_emacs_versions = qw(21 22 23);
my @emacs_flavors = ($EMPTY, qw(-el -gtk -nox -lucid));
my %known_obsolete_emacs;
for my $version (@obsolete_emacs_versions) {
    for my $flavor (@emacs_flavors) {

        my $package = 'emacs' . $version . $flavor;
        $known_obsolete_emacs{$package} = 1;
    }
}

my %known_libstdcs = map { $_ => 1 } qw(
  libstdc++2.9-glibc2.1
  libstdc++2.10
  libstdc++2.10-glibc2.2
  libstdc++3
  libstdc++3.0
  libstdc++4
  libstdc++5
  libstdc++6
  lib64stdc++6
);

my %known_tcls = map { $_ => 1 } qw(
  tcl74
  tcl8.0
  tcl8.2
  tcl8.3
  tcl8.4
  tcl8.5
);

my %known_tclxs = map { $_ => 1 } qw(
  tclx76
  tclx8.0.4
  tclx8.2
  tclx8.3
  tclx8.4
);

my %known_tks = map { $_ => 1 } qw(
  tk40
  tk8.0
  tk8.2
  tk8.3
  tk8.4
  tk8.5
);

my %known_libpngs = map { $_ => 1 } qw(
  libpng12-0
  libpng2
  libpng3
);

my @known_java_pkg = map { qr/$_/ } (
    'default-j(?:re|dk)(?:-headless)?',
    # java-runtime and javaX-runtime alternatives (virtual)
    'java\d*-runtime(?:-headless)?',
    # openjdk-X and sun-javaX
    '(openjdk-|sun-java)\d+-j(?:re|dk)(?:-headless)?',
    'gcj-(?:\d+\.\d+-)?jre(?:-headless)?', 'gcj-(?:\d+\.\d+-)?jdk', # gcj
    'gij',
    'java-gcj-compat(?:-dev|-headless)?', # deprecated/transitional packages
    'kaffe', 'cacao', 'jamvm',
    'classpath', # deprecated packages (removed in Squeeze)
);

# Python development packages that are used almost always just for building
# architecture-dependent modules.  Used to check for unnecessary build
# dependencies for architecture-independent source packages.
our $PYTHON_DEV = join(' | ',
    qw(python3-dev python3-all-dev),
    map { "python$_-dev" } qw(2.7 3 3.7 3.8 3.9));

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my $KNOWN_ESSENTIAL = $self->profile->load_data('fields/essential');
    my $KNOWN_TOOLCHAIN = $self->profile->load_data('fields/toolchain');
    my $KNOWN_METAPACKAGES = $self->profile->load_data('fields/metapackages');

    my $DH_ADDONS = $self->profile->load_data('common/dh_addons', $EQUAL);
    my %DH_ADDONS_VALUES = map { $DH_ADDONS->value($_) => 1 } $DH_ADDONS->all;

    my $OBSOLETE_PACKAGES
      = $self->profile->load_data('fields/obsolete-packages',qr/\s*=>\s*/);

    my $VIRTUAL_PACKAGES= $self->profile->load_data('fields/virtual-packages');

    my $javalib = 0;
    my $replaces = $processable->relation('Replaces');
    my %nag_once;
    $javalib = 1 if($pkg =~ m/^lib.*-java$/);
    for my $field (
        qw(Depends Pre-Depends Recommends Suggests Conflicts Provides Enhances Replaces Breaks)
    ) {
        next
          unless $processable->fields->declares($field);

        # get data and clean it
        my $data = $processable->fields->unfolded_value($field);
        my $javadep = 0;

        my (@seen_libstdcs, @seen_tcls, @seen_tclxs,@seen_tks, @seen_libpngs);

        my $is_dep_field
          = any { $field eq $_ } qw(Depends Pre-Depends Recommends Suggests);

        $self->hint('alternates-not-allowed', $field)
          if ($data =~ /\|/ && !$is_dep_field);
        $self->check_field($field, $data) if $is_dep_field;

        for my $dep (split /\s*,\s*/, $data) {
            my (@alternatives, @seen_obsolete_packages);
            push @alternatives, [_split_dep($_), $_]
              for (split /\s*\|\s*/, $dep);

            if ($is_dep_field) {
                push @seen_libstdcs, $alternatives[0][0]
                  if defined $known_libstdcs{$alternatives[0][0]};
                push @seen_tcls, $alternatives[0][0]
                  if defined $known_tcls{$alternatives[0][0]};
                push @seen_tclxs, $alternatives[0][0]
                  if defined $known_tclxs{$alternatives[0][0]};
                push @seen_tks, $alternatives[0][0]
                  if defined $known_tks{$alternatives[0][0]};
                push @seen_libpngs, $alternatives[0][0]
                  if defined $known_libpngs{$alternatives[0][0]};
            }

            # Only for (Pre-)?Depends.
            $self->hint('virtual-package-depends-without-real-package-depends',
                "$field: $alternatives[0][0]")
              if (
                   $VIRTUAL_PACKAGES->recognizes($alternatives[0][0])
                && ($field eq 'Depends' || $field eq 'Pre-Depends')
                && ($pkg ne 'base-files' || $alternatives[0][0] ne 'awk')
                # ignore phpapi- dependencies as adding an
                # alternative, real, package breaks its purpose
                && $alternatives[0][0] !~ m/^phpapi-/
              );

            # Check defaults for transitions.  Here, we only care
            # that the first alternative is current.
            $self->hint('depends-on-old-emacs', "$field: $alternatives[0][0]")
              if ( $is_dep_field
                && $known_obsolete_emacs{$alternatives[0][0]});

            for my $part_d (@alternatives) {
                my ($d_pkg, $d_march, $d_version, undef, undef, $rest,
                    $part_d_orig)
                  = @{$part_d};

                $self->hint('invalid-versioned-provides', $part_d_orig)
                  if ( $field eq 'Provides'
                    && $d_version->[0]
                    && $d_version->[0] ne $EQUAL);

                $self->hint('bad-provided-package-name', $d_pkg)
                  if $d_pkg !~ /^[a-z0-9][-+\.a-z0-9]+$/;

                $self->hint('breaks-without-version', $part_d_orig)
                  if ( $field eq 'Breaks'
                    && !$d_version->[0]
                    && !$VIRTUAL_PACKAGES->recognizes($d_pkg)
                    && !$replaces->satisfies($part_d_orig));

                $self->hint('conflicts-with-version', $part_d_orig)
                  if ($field eq 'Conflicts' && $d_version->[0]);

                $self->hint('obsolete-relation-form', "$field: $part_d_orig")
                  if (
                    $d_version && any { $d_version->[0] eq $_ }
                    ('<', '>'));

                $self->hint('bad-version-in-relation', "$field: $part_d_orig")
                  if ($d_version->[0] && !version_check($d_version->[1]));

                $self->hint('package-relation-with-self',
                    "$field: $part_d_orig")
                  if ($pkg eq $d_pkg)
                  && (!$d_march)
                  && ( $field ne 'Conflicts'
                    && $field ne 'Replaces'
                    && $field ne 'Provides');

                $self->hint('bad-relation', "$field: $part_d_orig") if $rest;

                push @seen_obsolete_packages, [$part_d_orig, $d_pkg]
                  if ( $OBSOLETE_PACKAGES->recognizes($d_pkg)
                    && $is_dep_field);

                $self->hint('depends-on-metapackage', "$field: $part_d_orig")
                  if ( $KNOWN_METAPACKAGES->recognizes($d_pkg)
                    && !$KNOWN_METAPACKAGES->recognizes($pkg)
                    && !$processable->is_transitional
                    && !$processable->is_meta_package
                    && $is_dep_field);

                # diffutils is a special case since diff was
                # renamed to diffutils, so a dependency on
                # diffutils effectively is a versioned one.
                $self->hint(
                    'depends-on-essential-package-without-using-version',
                    "$field: $part_d_orig")
                  if ( $KNOWN_ESSENTIAL->recognizes($d_pkg)
                    && !$d_version->[0]
                    && $is_dep_field
                    && $d_pkg ne 'diffutils'
                    && $d_pkg ne 'dash');

                $self->hint('package-depends-on-an-x-font-package',
                    "$field: $part_d_orig")
                  if ( $field =~ /^(?:Pre-)?Depends$/
                    && $d_pkg =~ /^xfont.*/
                    && $d_pkg ne 'xfonts-utils'
                    && $d_pkg ne 'xfonts-encodings');

                $self->hint('depends-on-packaging-dev',$field)
                  if (($field =~ /^(?:Pre-)?Depends$/|| $field eq 'Recommends')
                    && $d_pkg eq 'packaging-dev'
                    && !$processable->is_transitional
                    && !$processable->is_meta_package);

                $self->hint('needless-suggest-recommend-libservlet-java',
                    "$d_pkg")
                  if (($field eq 'Recommends' || $field eq 'Suggests')
                    && $d_pkg =~ m/libservlet[\d\.]+-java/);

                $self->hint('needlessly-depends-on-awk', $field)
                  if ( $d_pkg eq 'awk'
                    && !$d_version->[0]
                    && $is_dep_field
                    && $pkg ne 'base-files');

                $self->hint('depends-on-libdb1-compat', $field)
                  if ( $d_pkg eq 'libdb1-compat'
                    && $pkg !~ /^libc(?:6|6.1|0.3)/
                    && $field =~ /^(?:Pre-)?Depends$/);

                $self->hint('depends-on-python-minimal', $field,)
                  if ( $d_pkg =~ /^python[\d.]*-minimal$/
                    && $is_dep_field
                    && $pkg !~ /^python[\d.]*-minimal$/);

                $self->hint('doc-package-depends-on-main-package', $field)
                  if ("$d_pkg-doc" eq $pkg
                    && $field =~ /^(?:Pre-)?Depends$/);

                $self->hint(
                    'package-relation-with-perl-modules', "$field: $d_pkg"
                      # matches "perl-modules" (<= 5.20) as well as
                      # perl-modules-5.xx (>> 5.20)
                  )
                  if $d_pkg =~ /^perl-modules/
                  && $field ne 'Replaces'
                  && $processable->source_name ne 'perl';

                $self->hint('depends-exclusively-on-makedev', $field,)
                  if ( $field eq 'Depends'
                    && $d_pkg eq 'makedev'
                    && @alternatives == 1);

                $self->hint('lib-recommends-documentation',
                    "$field: $part_d_orig")
                  if ( $field eq 'Recommends'
                    && $pkg =~ m/^lib/
                    && $pkg !~ m/-(?:dev|docs?|tools|bin)$/
                    && $part_d_orig =~ m/-docs?$/);

                $self->hint('binary-package-depends-on-toolchain-package',
                    "$field: $part_d_orig")
                  if $KNOWN_TOOLCHAIN->recognizes($d_pkg)
                  && $is_dep_field
                  && $pkg !~ /^dh-/
                  && $pkg !~ /-(?:source|src)$/
                  && !$processable->is_transitional
                  && !$processable->is_meta_package
                  && !$DH_ADDONS_VALUES{$pkg};

                # default-jdk-doc must depend on openjdk-X-doc (or
                # classpath-doc) to be useful; other packages
                # should depend on default-jdk-doc if they want
                # the Java Core API.
                $self->hint('depends-on-specific-java-doc-package',$field)
                  if (
                       $is_dep_field
                    && $pkg ne 'default-jdk-doc'
                    && (   $d_pkg eq 'classpath-doc'
                        || $d_pkg =~ /openjdk-\d+-doc/));

                if ($javalib && $field eq 'Depends'){
                    foreach my $reg (@known_java_pkg){
                        if($d_pkg =~ m/$reg/){
                            $javadep++;
                            last;
                        }

                    }
                }
            }

            for my $d (@seen_obsolete_packages) {
                my ($dep, $pkg_name) = @{$d};
                my $replacement = $OBSOLETE_PACKAGES->value($pkg_name)
                  // $EMPTY;
                $replacement = ' => ' . $replacement
                  if $replacement ne $EMPTY;
                if ($pkg_name eq $alternatives[0][0]
                    or scalar @seen_obsolete_packages== scalar @alternatives) {
                    $self->hint(
                        'depends-on-obsolete-package',
                        "$field: $dep${replacement}"
                    );
                } else {
                    $self->hint(
                        'ored-depends-on-obsolete-package',
                        "$field: $dep${replacement}"
                    );
                }
            }

            # Only emit the tag if all the alternatives are
            # JVM/JRE/JDKs
            # - assume that <some-lib> | openjdk-X-jre-headless
            #   makes sense for now.
            if (scalar(@alternatives) == $javadep
                && !exists $nag_once{'needless-dependency-on-jre'}){
                $nag_once{'needless-dependency-on-jre'} = 1;
                $self->hint('needless-dependency-on-jre');
            }
        }
        $self->hint('package-depends-on-multiple-libstdc-versions',
            @seen_libstdcs)
          if (scalar @seen_libstdcs > 1);
        $self->hint('package-depends-on-multiple-tcl-versions', @seen_tcls)
          if (scalar @seen_tcls > 1);
        $self->hint('package-depends-on-multiple-tclx-versions', @seen_tclxs)
          if (scalar @seen_tclxs > 1);
        $self->hint('package-depends-on-multiple-tk-versions', @seen_tks)
          if (scalar @seen_tks > 1);
        $self->hint('package-depends-on-multiple-libpng-versions',
            @seen_libpngs)
          if (scalar @seen_libpngs > 1);
    }

    # If Conflicts or Breaks is set, make sure it's not inconsistent with
    # the other dependency fields.
    for my $conflict (qw/Conflicts Breaks/) {
        next
          unless $processable->fields->declares($conflict);

        for my $field (qw(Depends Pre-Depends Recommends Suggests)) {
            next
              unless $processable->fields->declares($field);

            my $relation = $processable->relation($field);
            for my $package (split /\s*,\s*/,
                $processable->fields->value($conflict)) {

                $self->hint('conflicts-with-dependency', $field, $package)
                  if $relation->satisfies($package);
            }
        }
    }

    return;
}

sub source {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my $KNOWN_ESSENTIAL = $self->profile->load_data('fields/essential');
    my $KNOWN_METAPACKAGES = $self->profile->load_data('fields/metapackages');
    my $NO_BUILD_DEPENDS= $self->profile->load_data('fields/no-build-depends');
    my $known_build_essential
      = $self->profile->load_data('fields/build-essential-packages');
    my $KNOWN_BUILD_PROFILES
      = $self->profile->load_data('fields/build-profiles');

    my $OBSOLETE_PACKAGES
      = $self->profile->load_data('fields/obsolete-packages',qr/\s*=>\s*/);

    my $VIRTUAL_PACKAGES= $self->profile->load_data('fields/virtual-packages');

    my @binpkgs = $processable->debian_control->installables;

    #Get number of arch-indep packages:
    my $arch_indep_packages = 0;
    my $arch_dep_packages = 0;

    for my $binpkg (@binpkgs) {
        my $arch = $processable->debian_control->installable_fields($binpkg)
          ->value('Architecture');

        if ($arch eq 'all') {
            $arch_indep_packages++;
        } else {
            $arch_dep_packages++;
        }
    }

    $self->hint('build-depends-indep-without-arch-indep')
      if ( $processable->fields->declares('Build-Depends-Indep')
        && $arch_indep_packages == 0);

    $self->hint('build-depends-arch-without-arch-dependent-binary')
      if ( $processable->fields->declares('Build-Depends-Arch')
        && $arch_dep_packages == 0);

    my %depend;
    for my $field (
        qw(Build-Depends Build-Depends-Indep Build-Depends-Arch Build-Conflicts Build-Conflicts-Indep Build-Conflicts-Arch)
    ) {
        if ($processable->fields->declares($field)) {

            my $is_dep_field = any { $field eq $_ }
            qw(Build-Depends Build-Depends-Indep Build-Depends-Arch);

            # get data and clean it
            my $data = $processable->fields->unfolded_value($field);

            $self->check_field($field, $data);
            $depend{$field} = $data;

            for my $dep (split /\s*,\s*/, $data) {
                my (@alternatives, @seen_obsolete_packages);
                push @alternatives, [_split_dep($_), $_]
                  for (split /\s*\|\s*/, $dep);

                $self->hint(
                    'virtual-package-depends-without-real-package-depends',
                    "$field: $alternatives[0][0]")
                  if ( $VIRTUAL_PACKAGES->recognizes($alternatives[0][0])
                    && $is_dep_field);

                for my $part_d (@alternatives) {
                    my ($d_pkg, undef, $d_version, $d_arch, $d_restr,
                        $rest,$part_d_orig)
                      = @{$part_d};

                    for my $arch (@{$d_arch->[0]}) {
                        $self->hint('invalid-arch-string-in-source-relation',
                            $arch, "[$field: $part_d_orig]")
                          if $arch eq 'all'
                          || (
                            !$self->profile->architectures
                            ->is_release_architecture(
                                $arch)
                            && !$self->profile->architectures->is_wildcard(
                                $arch));
                    }

                    for my $restrlist (@{$d_restr}) {
                        for my $prof (@{$restrlist}) {
                            $prof =~ s/^!//;
                            $self->hint(
                                'invalid-profile-name-in-source-relation',
                                "$prof [$field: $part_d_orig]"
                              )
                              unless $KNOWN_BUILD_PROFILES->recognizes($prof)
                              or $prof =~ /^pkg\.[a-z0-9][a-z0-9+.-]+\../;
                        }
                    }

                    if (   $d_pkg =~ /^openjdk-\d+-doc$/
                        or $d_pkg eq 'classpath-doc'){
                        $self->hint(
                            'build-depends-on-specific-java-doc-package',
                            $d_pkg);
                    }

                    if ($d_pkg eq 'java-compiler'){
                        $self->hint(
                            'build-depends-on-an-obsolete-java-package',
                            $d_pkg);
                    }

                    if (    $d_pkg =~ /^libdb\d+\.\d+.*-dev$/
                        and $is_dep_field) {
                        $self->hint('build-depends-on-versioned-berkeley-db',
                            "$field:$d_pkg");
                    }

                    $self->hint('conflicting-negation-in-source-relation',
                        "$field: $part_d_orig")
                      if ( $d_arch
                        && $d_arch->[1] != 0
                        && $d_arch->[1] ne @{ $d_arch->[0] });

                    $self->hint('depends-on-packaging-dev', $field)
                      if ($d_pkg eq 'packaging-dev');

                    $self->hint('build-depends-on-build-essential', $field)
                      if ($d_pkg eq 'build-essential');

                    $self->hint(
'build-depends-on-build-essential-package-without-using-version',
                        "$d_pkg [$field: $part_d_orig]"
                      )
                      if ($known_build_essential->recognizes($d_pkg)
                        && !$d_version->[1]);

                    $self->hint(
'build-depends-on-essential-package-without-using-version',
                        "$field: $part_d_orig"
                      )
                      if ( $KNOWN_ESSENTIAL->recognizes($d_pkg)
                        && !$d_version->[0]
                        && $d_pkg ne 'dash');
                    push @seen_obsolete_packages, [$part_d_orig, $d_pkg]
                      if ( $OBSOLETE_PACKAGES->recognizes($d_pkg)
                        && $is_dep_field);

                    $self->hint('build-depends-on-metapackage',
                        "$field: $part_d_orig")
                      if (  $KNOWN_METAPACKAGES->recognizes($d_pkg)
                        and $is_dep_field);

                    $self->hint('build-depends-on-non-build-package',
                        "$field: $part_d_orig")
                      if (  $NO_BUILD_DEPENDS->recognizes($d_pkg)
                        and $is_dep_field);

                    $self->hint('build-depends-on-1-revision',
                        "$field: $part_d_orig")
                      if ( $d_version->[0] eq '>='
                        && $d_version->[1] =~ /-1$/
                        && $is_dep_field);

                    $self->hint('bad-relation', "$field: $part_d_orig")
                      if $rest;

                    $self->hint('bad-version-in-relation',
                        "$field: $part_d_orig")
                      if ($d_version->[0]
                        && !version_check($d_version->[1]));

                    $self->hint(
                        'package-relation-with-perl-modules',
                        "$field: $part_d_orig"
                          # matches "perl-modules" (<= 5.20) as well as
                          # perl-modules-5.xx (>> 5.20)
                      )
                      if $d_pkg =~ /^perl-modules/
                      && $processable->source_name ne 'perl';
                }

                my $all_obsolete = 0;
                $all_obsolete = 1
                  if scalar @seen_obsolete_packages == @alternatives;
                for my $d (@seen_obsolete_packages) {
                    my ($dep, $pkg_name) = @{$d};
                    my $replacement = $OBSOLETE_PACKAGES->value($pkg_name)
                      // $EMPTY;

                    $replacement = ' => ' . $replacement
                      if $replacement ne $EMPTY;
                    if (   $pkg_name eq $alternatives[0][0]
                        or $all_obsolete) {
                        $self->hint('build-depends-on-obsolete-package',
                            "$field: $dep${replacement}");
                    } else {
                        $self->hint('ored-build-depends-on-obsolete-package',
                            "$field: $dep${replacement}");
                    }
                }
            }
        }
    }

    # Check for redundancies.
    my @to_check = (
        ['Build-Depends'],
        ['Build-Depends', 'Build-Depends-Indep'],
        ['Build-Depends', 'Build-Depends-Arch']);

    for my $fields (@to_check) {
        my $relation = Lintian::Relation->new->logical_and(
            map { $processable->relation($_) }@{$fields});

        for my $redundant_set ($relation->redundancies) {

            $self->hint(
                'redundant-build-prerequisites',
                join(', ', sort @{$redundant_set}));
        }
    }

    # Make sure build dependencies and conflicts are consistent.
    my $build_all = $processable->relation('Build-Depends-All');
    for (
        $depend{'Build-Conflicts'},
        $depend{'Build-Conflicts-Indep'},
        $depend{'Build-Conflicts-Arch'}
    ) {
        next unless $_;
        for my $conflict (split /\s*,\s*/, $_) {
            if ($build_all->satisfies($conflict)) {
                $self->hint('build-conflicts-with-build-dependency',$conflict);
            }
        }
    }

    my (@arch_dep_pkgs, @dbg_pkgs);
    foreach my $gproc ($group->get_binary_processables) {
        my $binpkg = $gproc->name;
        if ($binpkg =~ m/-dbg$/) {
            push(@dbg_pkgs, $gproc);
        } elsif ($processable->debian_control->installable_fields($binpkg)
            ->value('Architecture') ne 'all'){
            push @arch_dep_pkgs, $binpkg;
        }
    }
    my $dstr = join($VERTICAL_BAR, map { quotemeta($_) } @arch_dep_pkgs);
    my $depregex = qr/^(?:$dstr)$/;
    for my $dbg_proc (@dbg_pkgs) {
        my $deps = $processable->binary_relation($dbg_proc->name, 'strong');
        my $missing = 1;
        $missing = 0
          if $deps->matches($depregex, Lintian::Relation::VISIT_PRED_NAME);
        if ($missing && $dbg_proc->is_transitional) {
            # If it is a transitional package, allow it to depend
            # on another -dbg instead.
            $missing = 0
              if $deps->matches(qr/-dbg \Z/xsm,
                Lintian::Relation::VISIT_PRED_NAME);
        }
        $self->hint('dbg-package-missing-depends', $dbg_proc->name)
          if $missing;
    }

    # Check for a python*-dev build dependency in source packages that
    # build only arch: all packages.
    if ($arch_dep_packages == 0 and $build_all->satisfies($PYTHON_DEV)) {
        $self->hint('build-depends-on-python-dev-with-no-arch-any');
    }

    my $bdepends = $processable->relation('Build-Depends');

    # libmodule-build-perl
    # matches() instead of satisifies() because of possible OR relation
    $self->hint('libmodule-build-perl-needs-to-be-in-build-depends')
      if $processable->relation('Build-Depends-Indep')
      ->equals('libmodule-build-perl', Lintian::Relation::VISIT_PRED_NAME)
      && !$bdepends->equals('libmodule-build-perl',
        Lintian::Relation::VISIT_PRED_NAME);

    # libmodule-build-tiny-perl
    $self->hint('libmodule-build-tiny-perl-needs-to-be-in-build-depends')
      if $processable->relation('Build-Depends-Indep')
      ->satisfies('libmodule-build-tiny-perl')
      && !$bdepends->satisfies('libmodule-build-tiny-perl');

    return;
}

# splits "foo:bar (>= 1.2.3) [!i386 ia64] <stage1 !nocheck> <cross>" into
# ( "foo", "bar", [ ">=", "1.2.3" ], [ [ "i386", "ia64" ], 1 ], [ [ "stage1", "!nocheck" ] , [ "cross" ] ], "" )
#                                                         ^^^                                               ^^
#                     count of negated arches, if ! was given                                               ||
#                                                              rest (should always be "" for valid dependencies)
sub _split_dep {
    my $dep = shift;
    my ($pkg, $dmarch, $version, $darch, $restr)
      = ($EMPTY, $EMPTY, [$EMPTY,$EMPTY], [[], 0], []);

    if ($dep =~ s/^\s*([^<\s\[\(]+)\s*//) {
        ($pkg, $dmarch) = split(/:/, $1, 2);
        $dmarch //= $EMPTY;  # Ensure it is defined (in case there is no ":")
    }

    if (length $dep) {
        if ($dep
            =~ s/\s* \( \s* (<<|<=|>=|>>|[=<>]) \s* ([^\s(]+) \s* \) \s*//x) {
            @{$version} = ($1, $2);
        }
        if ($dep && $dep =~ s/\s*\[([^\]]+)\]\s*//) {
            my $t = $1;
            $darch->[0] = [split /\s+/, $t];
            my $negated = 0;
            for my $arch (@{ $darch->[0] }) {
                $negated++ if $arch =~ s/^!//;
            }
            $darch->[1] = $negated;
        }
        while ($dep && $dep =~ s/\s*<([^>]+)>\s*//) {
            my $t = $1;
            push(@{$restr}, [split /\s+/, $t]);
        }
    }

    return ($pkg, $dmarch, $version, $darch, $restr, $dep);
}

sub check_field {
    my ($self, $field, $data) = @_;

    my $processable = $self->processable;

    my $has_default_mta
      = $processable->relation($field)
      ->equals('default-mta', Lintian::Relation::VISIT_PRED_NAME);
    my $has_mail_transport_agent = $processable->relation($field)
      ->equals('mail-transport-agent', Lintian::Relation::VISIT_PRED_NAME);

    $self->hint('default-mta-dependency-not-listed-first',"$field: $data")
      if $processable->relation($field)
      ->matches(qr/\|\s+default-mta/, Lintian::Relation::VISIT_OR_CLAUSE_FULL);

    if ($has_default_mta) {
        $self->hint(
            'default-mta-dependency-does-not-specify-mail-transport-agent',
            "$field: $data")
          unless $has_mail_transport_agent;
    } elsif ($has_mail_transport_agent) {
        $self->hint(
            'mail-transport-agent-dependency-does-not-specify-default-mta',
            "$field: $data")
          unless $has_default_mta;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

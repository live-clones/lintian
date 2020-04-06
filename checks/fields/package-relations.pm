# fields/package-relations -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
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

package Lintian::fields::package_relations;

use v5.20;
use warnings;
use utf8;
use autodie;

use Dpkg::Version qw(version_check);
use List::MoreUtils qw(any);

use Lintian::Architecture qw(:all);
use Lintian::Data ();
use Lintian::Relation qw(:constants);

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $KNOWN_ESSENTIAL = Lintian::Data->new('fields/essential');
our $KNOWN_TOOLCHAIN = Lintian::Data->new('fields/toolchain');
our $KNOWN_METAPACKAGES = Lintian::Data->new('fields/metapackages');
our $NO_BUILD_DEPENDS = Lintian::Data->new('fields/no-build-depends');
our $known_build_essential
  = Lintian::Data->new('fields/build-essential-packages');
our $KNOWN_BUILD_PROFILES = Lintian::Data->new('fields/build-profiles');

# Still in the archive but shouldn't be the primary Emacs dependency.
our %known_obsolete_emacs = map { $_ => 1 }
  map { $_, $_.'-el', $_.'-gtk', $_.'-nox', $_.'-lucid' }
  qw(emacs21 emacs22 emacs23);

our %known_libstdcs = map { $_ => 1 } (
    'libstdc++2.9-glibc2.1', 'libstdc++2.10',
    'libstdc++2.10-glibc2.2','libstdc++3',
    'libstdc++3.0', 'libstdc++4',
    'libstdc++5','libstdc++6',
    'lib64stdc++6',
);

our %known_tcls = map { $_ => 1 }
  ('tcl74', 'tcl8.0', 'tcl8.2', 'tcl8.3', 'tcl8.4', 'tcl8.5',);

our %known_tclxs
  = map { $_ => 1 } ('tclx76', 'tclx8.0.4', 'tclx8.2', 'tclx8.3', 'tclx8.4',);

our %known_tks
  = map { $_ => 1 } ('tk40', 'tk8.0', 'tk8.2', 'tk8.3', 'tk8.4', 'tk8.5',);

our %known_libpngs = map { $_ => 1 } ('libpng12-0', 'libpng2', 'libpng3',);

our @known_java_pkg = map { qr/$_/ } (
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

our $DH_ADDONS = Lintian::Data->new('common/dh_addons', '=');
our %DH_ADDONS_VALUES = map { $DH_ADDONS->value($_) => 1 } $DH_ADDONS->all;

# Python development packages that are used almost always just for building
# architecture-dependent modules.  Used to check for unnecessary build
# dependencies for architecture-independent source packages.
our $PYTHON_DEV = join(' | ',
    qw(python-dev python-all-dev python3-dev python3-all-dev),
    map { "python$_-dev" } qw(2.7 3 3.4 3.5));

our $OBSOLETE_PACKAGES
  = Lintian::Data->new('fields/obsolete-packages',qr/\s*=>\s*/);
our $VIRTUAL_PACKAGES   = Lintian::Data->new('fields/virtual-packages');

sub installable {
    my ($self) = @_;

    my $pkg = $self->package;
    my $type = $self->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my $javalib = 0;
    my $replaces = $processable->relation('replaces');
    my %nag_once;
    $javalib = 1 if($pkg =~ m/^lib.*-java$/o);
    for my $field (
        qw(depends pre-depends recommends suggests conflicts provides enhances replaces breaks)
    ) {
        next unless defined $processable->field($field);
        #Get data and clean it
        my $data = $processable->unfolded_field($field);
        my $javadep = 0;

        my (@seen_libstdcs, @seen_tcls, @seen_tclxs,@seen_tks, @seen_libpngs);

        my $is_dep_field = sub {
            any { $_ eq $_[0] }qw(depends pre-depends recommends suggests);
        };

        $self->tag('alternates-not-allowed', $field)
          if ($data =~ /\|/ && !&$is_dep_field($field));
        $self->check_field($field, $data) if &$is_dep_field($field);

        for my $dep (split /\s*,\s*/, $data) {
            my (@alternatives, @seen_obsolete_packages);
            push @alternatives, [_split_dep($_), $_]
              for (split /\s*\|\s*/, $dep);

            if (&$is_dep_field($field)) {
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
            $self->tag('virtual-package-depends-without-real-package-depends',
                "$field: $alternatives[0][0]")
              if (
                   $VIRTUAL_PACKAGES->known($alternatives[0][0])
                && ($field eq 'depends' || $field eq 'pre-depends')
                && ($pkg ne 'base-files' || $alternatives[0][0] ne 'awk')
                # ignore phpapi- dependencies as adding an
                # alternative, real, package breaks its purpose
                && $alternatives[0][0] !~ m/^phpapi-/
              );

            # Check defaults for transitions.  Here, we only care
            # that the first alternative is current.
            $self->tag('depends-on-old-emacs', "$field: $alternatives[0][0]")
              if ( &$is_dep_field($field)
                && $known_obsolete_emacs{$alternatives[0][0]});

            for my $part_d (@alternatives) {
                my ($d_pkg, undef, $d_version, undef, undef, $rest,
                    $part_d_orig)= @$part_d;

                $self->tag('invalid-versioned-provides', $part_d_orig)
                  if ( $field eq 'provides'
                    && $d_version->[0]
                    && $d_version->[0] ne '=');

                $self->tag('bad-provided-package-name', $d_pkg)
                  if $d_pkg !~ /^[a-z0-9][-+\.a-z0-9]+$/;

                $self->tag('breaks-without-version', $part_d_orig)
                  if ( $field eq 'breaks'
                    && !$d_version->[0]
                    && !$VIRTUAL_PACKAGES->known($d_pkg)
                    && !$replaces->implies($part_d_orig));

                $self->tag('conflicts-with-version', $part_d_orig)
                  if ($field eq 'conflicts' && $d_version->[0]);

                $self->tag('obsolete-relation-form', "$field: $part_d_orig")
                  if (
                    $d_version && any { $d_version->[0] eq $_ }
                    ('<', '>'));

                $self->tag('bad-version-in-relation', "$field: $part_d_orig")
                  if ($d_version->[0] && !version_check($d_version->[1]));

                $self->tag('package-relation-with-self',"$field: $part_d_orig")
                  if ($pkg eq $d_pkg)
                  && ( $field ne 'conflicts'
                    && $field ne 'replaces'
                    && $field ne 'provides');

                $self->tag('bad-relation', "$field: $part_d_orig") if $rest;

                push @seen_obsolete_packages, [$part_d_orig, $d_pkg]
                  if ( $OBSOLETE_PACKAGES->known($d_pkg)
                    && &$is_dep_field($field));

                $self->tag('depends-on-metapackage', "$field: $part_d_orig")
                  if (  $KNOWN_METAPACKAGES->known($d_pkg)
                    and not $KNOWN_METAPACKAGES->known($pkg)
                    and not $processable->is_pkg_class('any-meta')
                    and &$is_dep_field($field));

                # diffutils is a special case since diff was
                # renamed to diffutils, so a dependency on
                # diffutils effectively is a versioned one.
                $self->tag(
                    'depends-on-essential-package-without-using-version',
                    "$field: $part_d_orig")
                  if ( $KNOWN_ESSENTIAL->known($d_pkg)
                    && !$d_version->[0]
                    && &$is_dep_field($field)
                    && $d_pkg ne 'diffutils'
                    && $d_pkg ne 'dash');

                $self->tag('package-depends-on-an-x-font-package',
                    "$field: $part_d_orig")
                  if ( $field =~ /^(?:pre-)?depends$/
                    && $d_pkg =~ /^xfont.*/
                    && $d_pkg ne 'xfonts-utils'
                    && $d_pkg ne 'xfonts-encodings');

                $self->tag('depends-on-packaging-dev',$field)
                  if (($field =~ /^(?:pre-)?depends$/|| $field eq 'recommends')
                    && $d_pkg eq 'packaging-dev'
                    && !$processable->is_pkg_class('any-meta'));

                $self->tag('needless-suggest-recommend-libservlet-java',
                    "$d_pkg")
                  if (($field eq 'recommends' || $field eq 'suggests')
                    && $d_pkg =~ m/libservlet[\d\.]+-java/);

                $self->tag('needlessly-depends-on-awk', $field)
                  if ( $d_pkg eq 'awk'
                    && !$d_version->[0]
                    && &$is_dep_field($field)
                    && $pkg ne 'base-files');

                $self->tag('depends-on-libdb1-compat', $field)
                  if ( $d_pkg eq 'libdb1-compat'
                    && $pkg !~ /^libc(?:6|6.1|0.3)/
                    && $field =~ m/^(?:pre-)?depends$/o);

                $self->tag('depends-on-python-minimal', $field,)
                  if ( $d_pkg =~ /^python[\d.]*-minimal$/
                    && &$is_dep_field($field)
                    && $pkg !~ /^python[\d.]*-minimal$/);

                $self->tag('doc-package-depends-on-main-package', $field)
                  if ("$d_pkg-doc" eq $pkg
                    && $field =~ /^(?:pre-)?depends$/);

                $self->tag(
                    'package-relation-with-perl-modules', "$field: $d_pkg"
                      # matches "perl-modules" (<= 5.20) as well as
                      # perl-modules-5.xx (>> 5.20)
                  )
                  if $d_pkg =~ /^perl-modules/
                  && $field ne 'replaces'
                  && $processable->source ne 'perl';

                $self->tag('depends-exclusively-on-makedev', $field,)
                  if ( $field eq 'depends'
                    && $d_pkg eq 'makedev'
                    && @alternatives == 1);

                $self->tag('lib-recommends-documentation',
                    "$field: $part_d_orig")
                  if ( $field eq 'recommends'
                    && $pkg =~ m/^lib/
                    && $pkg !~ m/-(?:dev|docs?|tools|bin)$/
                    && $part_d_orig =~ m/-docs?$/);

                $self->tag('binary-package-depends-on-toolchain-package',
                    "$field: $part_d_orig")
                  if $KNOWN_TOOLCHAIN->known($d_pkg)
                  and &$is_dep_field($field)
                  and not $pkg =~ m/^dh-/
                  and not $pkg =~ m/-(source|src)$/
                  and not $processable->is_pkg_class('any-meta')
                  and not $DH_ADDONS_VALUES{$pkg};

                # default-jdk-doc must depend on openjdk-X-doc (or
                # classpath-doc) to be useful; other packages
                # should depend on default-jdk-doc if they want
                # the Java Core API.
                $self->tag('depends-on-specific-java-doc-package',$field)
                  if (
                       &$is_dep_field($field)
                    && $pkg ne 'default-jdk-doc'
                    && (   $d_pkg eq 'classpath-doc'
                        || $d_pkg =~ m/openjdk-\d+-doc/o));

                if ($javalib && $field eq 'depends'){
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
                my $replacement = $OBSOLETE_PACKAGES->value($pkg_name)// '';
                $replacement = ' => ' . $replacement
                  if $replacement ne '';
                if ($pkg_name eq $alternatives[0][0]
                    or scalar @seen_obsolete_packages== scalar @alternatives) {
                    $self->tag(
                        'depends-on-obsolete-package',
                        "$field: $dep${replacement}"
                    );
                } else {
                    $self->tag(
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
                $self->tag('needless-dependency-on-jre');
            }
        }
        $self->tag('package-depends-on-multiple-libstdc-versions',
            @seen_libstdcs)
          if (scalar @seen_libstdcs > 1);
        $self->tag('package-depends-on-multiple-tcl-versions', @seen_tcls)
          if (scalar @seen_tcls > 1);
        $self->tag('package-depends-on-multiple-tclx-versions', @seen_tclxs)
          if (scalar @seen_tclxs > 1);
        $self->tag('package-depends-on-multiple-tk-versions', @seen_tks)
          if (scalar @seen_tks > 1);
        $self->tag('package-depends-on-multiple-libpng-versions',@seen_libpngs)
          if (scalar @seen_libpngs > 1);
    }

    # If Conflicts or Breaks is set, make sure it's not inconsistent with
    # the other dependency fields.
    for my $conflict (qw/conflicts breaks/) {
        next unless $processable->field($conflict);
        for my $field (qw(depends pre-depends recommends suggests)) {
            next unless $processable->field($field);
            my $relation = $processable->relation($field);
            for my $package (split /\s*,\s*/, $processable->field($conflict)) {
                $self->tag('conflicts-with-dependency', $field, $package)
                  if $relation->implies($package);
            }
        }
    }

    return;
}

sub source {
    my ($self) = @_;

    my $pkg = $self->package;
    my $type = $self->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my @binpkgs = $processable->binaries;

    #Get number of arch-indep packages:
    my $arch_indep_packages = 0;
    my $arch_dep_packages = 0;
    foreach my $binpkg (@binpkgs) {
        my $arch = $processable->binary_field($binpkg, 'architecture', '');
        if ($arch eq 'all') {
            $arch_indep_packages++;
        } else {
            $arch_dep_packages++;
        }
    }

    $self->tag('build-depends-indep-without-arch-indep')
      if (defined $processable->field('build-depends-indep')
        && $arch_indep_packages == 0);
    $self->tag('build-depends-arch-without-arch-dependent-binary')
      if (defined $processable->field('build-depends-arch')
        && $arch_dep_packages == 0);

    my $is_dep_field = sub {
        any { $_ eq $_[0] }
        qw(build-depends build-depends-indep build-depends-arch);
    };

    my %depend;
    for my $field (
        qw(build-depends build-depends-indep build-depends-arch build-conflicts build-conflicts-indep build-conflicts-arch)
    ) {
        if (defined $processable->field($field)) {
            #Get data and clean it
            my $data = $processable->unfolded_field($field);

            $self->check_field($field, $data);
            $depend{$field} = $data;

            for my $dep (split /\s*,\s*/, $data) {
                my (@alternatives, @seen_obsolete_packages);
                push @alternatives, [_split_dep($_), $_]
                  for (split /\s*\|\s*/, $dep);

                $self->tag(
                    'virtual-package-depends-without-real-package-depends',
                    "$field: $alternatives[0][0]")
                  if ( $VIRTUAL_PACKAGES->known($alternatives[0][0])
                    && &$is_dep_field($field));

                for my $part_d (@alternatives) {
                    my ($d_pkg, undef, $d_version, $d_arch, $d_restr,
                        $rest,$part_d_orig)
                      = @$part_d;

                    for my $arch (@{$d_arch->[0]}) {
                        if ($arch eq 'all' || !is_arch_or_wildcard($arch)){
                            $self->tag(
                                'invalid-arch-string-in-source-relation',
                                "$arch [$field: $part_d_orig]");
                        }
                    }

                    for my $restrlist (@{$d_restr}) {
                        for my $prof (@{$restrlist}) {
                            $prof =~ s/^!//;
                            $self->tag(
                                'invalid-profile-name-in-source-relation',
                                "$prof [$field: $part_d_orig]"
                              )
                              unless $KNOWN_BUILD_PROFILES->known($prof)
                              or $prof =~ /^pkg\.[a-z0-9][a-z0-9+.-]+\../;
                        }
                    }

                    if (   $d_pkg =~ m/^openjdk-\d+-doc$/o
                        or $d_pkg eq 'classpath-doc'){
                        $self->tag(
                            'build-depends-on-specific-java-doc-package',
                            $d_pkg);
                    }

                    if ($d_pkg eq 'java-compiler'){
                        $self->tag('build-depends-on-an-obsolete-java-package',
                            $d_pkg);
                    }

                    if (    $d_pkg =~ m/^libdb\d+\.\d+.*-dev$/o
                        and &$is_dep_field($field)) {
                        $self->tag('build-depends-on-versioned-berkeley-db',
                            "$field:$d_pkg");
                    }

                    $self->tag('conflicting-negation-in-source-relation',
                        "$field: $part_d_orig")
                      unless (not $d_arch
                        or $d_arch->[1] == 0
                        or $d_arch->[1] eq @{ $d_arch->[0] });

                    $self->tag('depends-on-packaging-dev', $field)
                      if ($d_pkg eq 'packaging-dev');

                    $self->tag('build-depends-on-build-essential', $field)
                      if ($d_pkg eq 'build-essential');

                    $self->tag(
'build-depends-on-build-essential-package-without-using-version',
                        "$d_pkg [$field: $part_d_orig]"
                      )
                      if ($known_build_essential->known($d_pkg)
                        && !$d_version->[1]);

                    $self->tag(
'build-depends-on-essential-package-without-using-version',
                        "$field: $part_d_orig"
                      )
                      if ( $KNOWN_ESSENTIAL->known($d_pkg)
                        && !$d_version->[0]
                        && $d_pkg ne 'dash');
                    push @seen_obsolete_packages, [$part_d_orig, $d_pkg]
                      if ( $OBSOLETE_PACKAGES->known($d_pkg)
                        && &$is_dep_field($field));

                    $self->tag('build-depends-on-metapackage',
                        "$field: $part_d_orig")
                      if (  $KNOWN_METAPACKAGES->known($d_pkg)
                        and &$is_dep_field($field));

                    $self->tag('build-depends-on-non-build-package',
                        "$field: $part_d_orig")
                      if (  $NO_BUILD_DEPENDS->known($d_pkg)
                        and &$is_dep_field($field));

                    $self->tag('build-depends-on-1-revision',
                        "$field: $part_d_orig")
                      if ( $d_version->[0] eq '>='
                        && $d_version->[1] =~ /-1$/
                        && &$is_dep_field($field));

                    $self->tag('bad-relation', "$field: $part_d_orig")
                      if $rest;

                    $self->tag('bad-version-in-relation',
                        "$field: $part_d_orig")
                      if ($d_version->[0]
                        && !version_check($d_version->[1]));

                    $self->tag(
                        'package-relation-with-perl-modules',
                        "$field: $part_d_orig"
                          # matches "perl-modules" (<= 5.20) as well as
                          # perl-modules-5.xx (>> 5.20)
                      )
                      if $d_pkg =~ /^perl-modules/
                      && $processable->source ne 'perl';
                }

                my $all_obsolete = 0;
                $all_obsolete = 1
                  if scalar @seen_obsolete_packages == @alternatives;
                for my $d (@seen_obsolete_packages) {
                    my ($dep, $pkg_name) = @{$d};
                    my $replacement = $OBSOLETE_PACKAGES->value($pkg_name)
                      // '';
                    next if $processable->source eq 'lintian';
                    $replacement = ' => ' . $replacement
                      if $replacement ne '';
                    if (   $pkg_name eq $alternatives[0][0]
                        or $all_obsolete) {
                        $self->tag('build-depends-on-obsolete-package',
                            "$field: $dep${replacement}");
                    } else {
                        $self->tag('ored-build-depends-on-obsolete-package',
                            "$field: $dep${replacement}");
                    }
                }
            }
        }
    }

    # Check for duplicates.
    my $build_all = $processable->relation('build-depends-all');
    my @dups = $build_all->duplicates;
    for my $dup (@dups) {
        $self->tag('package-has-a-duplicate-build-relation',join(', ', @$dup));
    }

    # Make sure build dependencies and conflicts are consistent.
    for (
        $depend{'build-conflicts'},
        $depend{'build-conflicts-indep'},
        $depend{'build-conflicts-arch'}
    ) {
        next unless $_;
        for my $conflict (split /\s*,\s*/, $_) {
            if ($build_all->implies($conflict)) {
                $self->tag('build-conflicts-with-build-dependency', $conflict);
            }
        }
    }

    my (@arch_dep_pkgs, @dbg_pkgs);
    foreach my $gproc ($group->get_binary_processables) {
        my $binpkg = $gproc->name;
        if ($binpkg =~ m/-dbg$/) {
            push(@dbg_pkgs, $gproc);
        } elsif (
            $processable->binary_field($binpkg, 'architecture', '') ne 'all'){
            push @arch_dep_pkgs, $binpkg;
        }
    }
    my $dstr = join('|', map { quotemeta($_) } @arch_dep_pkgs);
    my $depregex = qr/^(?:$dstr)$/;
    for my $dbg_proc (@dbg_pkgs) {
        my $deps = $processable->binary_relation($dbg_proc->name, 'strong');
        my $missing = 1;
        $missing = 0 if $deps->matches($depregex, VISIT_PRED_NAME);
        if ($missing and $dbg_proc->is_pkg_class('transitional')) {
            # If it is a transitional package, allow it to depend
            # on another -dbg instead.
            $missing = 0
              if $deps->matches(qr/-dbg \Z/xsm, VISIT_PRED_NAME);
        }
        $self->tag('dbg-package-missing-depends', $dbg_proc->name)
          if $missing;
    }

    # Check for a python*-dev build dependency in source packages that
    # build only arch: all packages.
    if ($arch_dep_packages == 0 and $build_all->implies($PYTHON_DEV)) {
        $self->tag('build-depends-on-python-dev-with-no-arch-any');
    }

    my $bdepends = $processable->relation('build-depends');

    # libmodule-build-perl
    # matches() instead of implies() because of possible OR relation
    $self->tag('libmodule-build-perl-needs-to-be-in-build-depends')
      if $processable->relation('build-depends-indep')
      ->matches(qr/^libmodule-build-perl$/, VISIT_PRED_NAME)
      && !$bdepends->matches(qr/^libmodule-build-perl$/,VISIT_PRED_NAME);

    # libmodule-build-tiny-perl
    $self->tag('libmodule-build-tiny-perl-needs-to-be-in-build-depends')
      if $processable->relation('build-depends-indep')
      ->implies('libmodule-build-tiny-perl')
      && !$bdepends->implies('libmodule-build-tiny-perl');

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
      = ('', '', ['',''], [[], 0], []);

    if ($dep =~ s/^\s*([^<\s\[\(]+)\s*//) {
        ($pkg, $dmarch) = split(/:/, $1, 2);
        $dmarch //= '';  # Ensure it is defined (in case there is no ":")
    }

    if (length $dep) {
        if ($dep
            =~ s/\s* \( \s* (<<|<=|<|=|>=|>>|>) \s* ([^\s(]+) \s* \) \s*//x) {
            @$version = ($1, $2);
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
            push @$restr, [split /\s+/, $t];
        }
    }

    return ($pkg, $dmarch, $version, $darch, $restr, $dep);
}

sub check_field {
    my ($self, $field, $data) = @_;

    my $processable = $self->processable;

    my $has_default_mta
      = $processable->relation($field)
      ->matches(qr/^default-mta$/, VISIT_PRED_NAME);
    my $has_mail_transport_agent = $processable->relation($field)
      ->matches(qr/^mail-transport-agent$/, VISIT_PRED_NAME);

    $self->tag('default-mta-dependency-not-listed-first',"$field: $data")
      if $processable->relation($field)
      ->matches(qr/\|\s+default-mta/, VISIT_OR_CLAUSE_FULL);

    if ($has_default_mta) {
        $self->tag(
            'default-mta-dependency-does-not-specify-mail-transport-agent',
            "$field: $data")
          unless $has_mail_transport_agent;
    } elsif ($has_mail_transport_agent) {
        $self->tag(
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

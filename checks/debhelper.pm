# debhelper format -- lintian check script -*- perl -*-

# Copyright © 1999 by Joey Hess
# Copyright © 2016-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::debhelper;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use List::MoreUtils qw(any firstval);
use List::UtilsBy qw(min_by);
use Text::LevenshteinXS qw(distance);

use Lintian::Data;
use Lintian::Relation qw(:constants);

use constant EMPTY => q{};
use constant UNDERSCORE => q{_};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# If there is no debian/compat file present but cdbs is being used, cdbs will
# create one automatically.  Currently it always uses compatibility level 5.
# It may be better to look at what version of cdbs the package depends on and
# from that derive the compatibility level....
my $cdbscompat = 5;

my $maint_commands = Lintian::Data->new('debhelper/maint_commands');
my $dh_commands_depends = Lintian::Data->new('debhelper/dh_commands', '=');
my $filename_configs = Lintian::Data->new('debhelper/filename-config-files');
my $dh_ver_deps= Lintian::Data->new('debhelper/dh_commands-manual', qr/\|\|/);
my $dh_addons = Lintian::Data->new('common/dh_addons', '=');
my $dh_addons_manual
  = Lintian::Data->new('debhelper/dh_addons-manual', qr/\|\|/);
my $compat_level = Lintian::Data->new('debhelper/compat-level',qr/=/);

my $MISC_DEPENDS = Lintian::Relation->new('${misc:Depends}');

my @KNOWN_DH_COMMANDS= map { $_, $_ . '-arch', $_ . '-indep' }
  map { 'override' . $_, 'execute_before' . $_, 'execute_after' . $_ }
  map { UNDERSCORE . $_ } $dh_commands_depends->all;

sub source {
    my ($self) = @_;

    my $processable = $self->processable;
    my $group = $self->group;

    my $droot = $processable->patched->resolve_path('debian/');
    my ($drules, $dh_bd_version, $level);

    my $seencommand = '';
    my $needbuilddepends = '';
    my $needdhexecbuilddepends = '';
    my $needtomodifyscripts = '';
    my $compat = 0;
    my $seendhcleank = '';
    my (%missingbdeps, %missingbdeps_addons, $maybe_skipping, $dhcompatvalue);
    my $inclcdbs = 0;

    my ($bdepends_noarch, $bdepends, %build_systems, $uses_autotools_dev_dh);
    $bdepends = $processable->relation('Build-Depends-All');
    my $seen_dh = 0;
    my $seen_dh_dynamic = 0;
    my $seen_dh_systemd = 0;
    my $seen_dh_parallel = 0;
    my %seen = (
        'python2' => 0,
        'python3' => 0,
        'runit'   => 0,
        'sphinxdoc' => 0,
    );
    my %overrides;

    $drules = $droot->child('rules') if $droot;

    return unless $drules and $drules->is_open_ok;

    open(my $rules_fd, '<', $drules->unpacked_path);

    my $command_prefix_pattern = qr/\s+[@+-]?(?:\S+=\S+\s+)*/;

    foreach (qw(python2 python3)) {
        $seen{$_} = 1 if $bdepends->implies("dh-sequence-$_");
    }

    while (<$rules_fd>) {
        while (s,\\$,, and defined(my $cont = <$rules_fd>)) {
            $_ .= $cont;
        }
        if (/^ifn?(?:eq|def)\s/) {
            $maybe_skipping++;
        } elsif (/^endif\s/) {
            $maybe_skipping--;
        }

        next if /^\s*\#/;
        if (m/^$command_prefix_pattern(dh_(?!autoreconf)\S+)/) {
            my $dhcommand = $1;
            $build_systems{'debhelper'} = 1
              if not exists($build_systems{'dh'});

            if ($dhcommand eq 'dh_installmanpages') {
                $self->tag('dh_installmanpages-is-obsolete', "line $.");
            }
            if (   $dhcommand eq 'dh_autotools-dev_restoreconfig'
                or $dhcommand eq 'dh_autotools-dev_updateconfig') {
                $self->tag('debhelper-tools-from-autotools-dev-are-deprecated',
                    "$dhcommand (line $.)");
                $uses_autotools_dev_dh = 1;
            }

            # Record if we've seen specific helpers, special-casing
            # "dh_python" as Python 2.x.
            $seen{'python2'} = 1 if $dhcommand eq 'dh_python2';
            foreach my $k (keys %seen) {
                $seen{$k} = 1 if $dhcommand eq "dh_$k";
            }

            if ($dhcommand eq 'dh_clean' and m/\s+\-k(?:\s+.*)?$/s) {
                $seendhcleank = 1;
            }

            # if command is passed -n, it does not modify the scripts
            if ($maint_commands->known($dhcommand) and not m/\s+\-n\s+/) {
                $needtomodifyscripts = 1;
            }

           # If debhelper commands are wrapped in make conditionals, assume the
           # maintainer knows what they're doing and don't check build
           # dependencies.
            unless ($maybe_skipping) {
                if ($dh_ver_deps->known($dhcommand)) {
                    my $dep = $dh_ver_deps->value($dhcommand);
                    $missingbdeps{$dep} = $dhcommand;
                } elsif ($dh_commands_depends->known($dhcommand)) {
                    my $dep = $dh_commands_depends->value($dhcommand);
                    $missingbdeps{$dep} = $dhcommand;
                }
            }
            $seencommand = 1;
            $needbuilddepends = 1;
        } elsif (m,^(?:$command_prefix_pattern)dh\s+,) {
            $build_systems{'dh'} = 1;
            delete($build_systems{'debhelper'});
            $seen_dh = 1;
            $seencommand = 1;
            $seen_dh_dynamic = 1 if m/\$[({]\w/;
            $seen_dh_parallel = $. if m/--parallel/;
            $needbuilddepends = 1;
            $needtomodifyscripts = 1;

            while (m/\s--with(?:=|\s+)(['"]?)(\S+)\1/g) {
                my $addon_list = $2;
                for my $addon (split(/,/, $addon_list)) {
                    my $orig_addon = $addon;
                    $addon =~ y,-,_,;
                    my $depends = $dh_addons_manual->value($addon)
                      || $dh_addons->value($addon);
                    if ($addon eq 'autotools_dev') {
                        $self->tag(
'debhelper-tools-from-autotools-dev-are-deprecated',
                            "dh ... --with ${orig_addon} (line $.)"
                        );
                        $uses_autotools_dev_dh = 1;
                    }
                    $seen_dh_systemd = $. if $addon eq 'systemd';
                    $self->tag(
                        'dh-quilt-addon-but-quilt-source-format',
                        "dh ... --with ${orig_addon}",
                        "(line $.)"
                      )
                      if $addon eq 'quilt'
                      and ($processable->field('Format') // EMPTY) eq
                      '3.0 (quilt)';
                    if (defined $depends) {
                        $missingbdeps_addons{$depends} = $addon;
                    }
                    foreach my $k (keys %seen) {
                        $seen{$k} = 1 if $addon eq $k;
                    }
                }
            }
        } elsif (m,^include\s+/usr/share/cdbs/1/rules/debhelper.mk,
            or m,^include\s+/usr/share/R/debian/r-cran.mk,) {
            $build_systems{'cdbs-with-debhelper.mk'} = 1;
            delete($build_systems{'cdbs-without-debhelper.mk'});
            $seencommand = 1;
            $needbuilddepends = 1;
            $needtomodifyscripts = 1;
            $inclcdbs = 1;

            # CDBS sets DH_COMPAT but doesn't export it.
            $dhcompatvalue = $cdbscompat;
        } elsif (/^\s*export\s+DH_COMPAT\s*:?=\s*([^\s]+)/) {
            $level = $1;
        } elsif (/^\s*export\s+DH_COMPAT/) {
            $level = $dhcompatvalue if $dhcompatvalue;
        } elsif (/^\s*DH_COMPAT\s*:?=\s*([^\s]+)/) {
            $dhcompatvalue = $1;
            # one can export and then set the value:
            $level = $1 if ($level);

        } elsif (/^[^:]*(override|execute_(?:after|before))\s+(dh_[^:]*):/) {
            $self->tag('typo-in-debhelper-override-target',
                "$1 $2", '->', "$1_$2","(line $.)");

        } elsif (/^([^:]*_dh_[^:]*):/) {
            my $alltargets = $1;
            # can be multiple targets per rule.
            my @targets = split(/\s+/, $alltargets);
            my @dh_targets = grep { /_dh_/ } @targets;

            # If maintainer is using wildcards, it's unlikely to be a typo.
            my @no_wildcards = grep { !/%/ } @dh_targets;

            my $lc = List::Compare->new(\@no_wildcards, \@KNOWN_DH_COMMANDS);
            my @unknown = $lc->get_Lonly;

            for my $target (@unknown) {

                my %distance
                  = map { $_ => distance($target, $_) } @KNOWN_DH_COMMANDS;
                my @near = grep { $distance{$_} < 3 } keys %distance;
                my $nearest = min_by { $distance{$_} } @near;

                $self->tag('typo-in-debhelper-override-target',
                    $target, '->', $nearest, "(line $.)")
                  if length $nearest;
            }

            for my $target (@no_wildcards) {

                next
                  unless $target
                  =~ /^(override|execute_(?:before|after))_dh_([^\s]+?)(-arch|-indep|)$/;

                my $prefix = $1;
                my $cmd = $2;
                my $arch = $3;
                my $dhcommand = "dh_$cmd";
                $overrides{$dhcommand} = [$., $arch];
                $needbuilddepends = 1;

                next
                  if $dh_commands_depends->known($dhcommand);

                # Unknown command, so check for likely misspellings
                my $missingauto = firstval { "dh_auto_$cmd" eq $_ }
                $dh_commands_depends->all;
                $self->tag('typo-in-debhelper-override-target',
                    "${prefix}_$dhcommand", '->', "${prefix}_$missingauto",
                    "(line $.)")
                  if length $missingauto;
            }

        } elsif (m,^include\s+/usr/share/cdbs/,) {
            $inclcdbs = 1;
            $build_systems{'cdbs-without-debhelper.mk'} = 1
              if not exists($build_systems{'cdbs-with-debhelper.mk'});
        } elsif (
            m{
              ^include \s+
                 /usr/share/(?:
                   dh-php/pkg-pecl\.mk
                  |blends-dev/rules
                 )
              }xsm
        ) {
            # All of these indirectly use dh.
            $seencommand = 1;
            $build_systems{'dh'} = 1;
            delete($build_systems{'debhelper'});
        } elsif (
            m{
              ^include \s+
                 /usr/share/pkg-kde-tools/qt-kde-team/\d+/debian-qt-kde\.mk
              }xsm
        ) {
            $inclcdbs = 1;
            $build_systems{'dhmk'} = 1;
            delete($build_systems{'debhelper'});
        }
    }
    close($rules_fd);

    # Variables could contain any add-ons; assume we have seen them all
    if ($seen_dh_dynamic) {
        %seen = map { $_ => 1 } keys %seen;
    }

    unless ($inclcdbs){
        # Okay - d/rules does not include any file in /usr/share/cdbs/
        $self->tag('unused-build-dependency-on-cdbs')
          if ($bdepends->implies('cdbs'));
    }

    if (%build_systems) {
        my @systems = sort(keys(%build_systems));
        $self->tag('debian-build-system', join(', ', @systems));
    } else {
        $self->tag('debian-build-system', 'other');
    }

    unless ($seencommand or $inclcdbs) {
        $self->tag('package-does-not-use-debhelper-or-cdbs');
        return;
    }

    my @pkgs = $processable->binaries;
    my $single_pkg = '';
    $single_pkg =  $processable->binary_package_type($pkgs[0])
      if scalar @pkgs == 1;

    for my $binpkg (@pkgs) {
        next if $processable->binary_package_type($binpkg) ne 'deb';
        my $strong = $processable->binary_relation($binpkg, 'strong');
        my $all = $processable->binary_relation($binpkg, 'all');

        if (!$all->implies($MISC_DEPENDS)) {
            $self->tag('debhelper-but-no-misc-depends', $binpkg);
        } else {
            $self->tag('weak-dependency-on-misc-depends', $binpkg)
              unless $strong->implies($MISC_DEPENDS);
        }
    }

    for my $proc ($group->get_processables('binary')) {
        my $binpkg = $proc->name;
        my $breaks = $processable->binary_relation($binpkg, 'Breaks');
        my $strong = $processable->binary_relation($binpkg, 'strong');
        $self->tag('package-uses-dh-runit-but-lacks-breaks-substvar', $binpkg)
          if $seen{'runit'}
          and $strong->implies('runit')
          and any { m,^etc/sv/, } $proc->installed->sorted_list
          and not $breaks->implies('${runit:Breaks}');
    }

    my $compatnan = 0;
    my $compatvirtual;
    my $compat_file = $droot->child('compat');
    my $visit = sub {
        return 0 unless m,^debhelper-compat \(= (\d+)\)$,;
        $level = $1;
        $compatvirtual = $level;
        $self->tag('debhelper-compat-virtual-relation', $compatvirtual);
        return 1;
    };
    $bdepends->visit($visit, VISIT_PRED_FULL | VISIT_STOP_FIRST_MATCH);

    # Check the compat file.  Do this separately from looping over all
    # of the other files since we use the compat value when checking
    # for brace expansion.
    if ($compat_file and $compat_file->is_open_ok) {
        open(my $fd, '<', $compat_file->unpacked_path);
        while (<$fd>) {
            if ($. == 1) {
                $compat = $_;

                # trim both ends
                $compat =~ s/^\s+|\s+$//g;

            } elsif (m/^\d/) {
                $self->tag('debhelper-compat-file-contains-multiple-levels',
                    "(line $.)");
            }
        }
        close($fd);
        if ($compat ne '') {
            my $compat_value = $compat;
            # Recommend people use debhelper-compat (introduced in debhelper
            # 11.1.5~alpha1) over debian/compat, except for experimental/beta
            # versions.
            if ($compat !~ m/^\d+$/) {
                $self->tag('debhelper-compat-not-a-number', $compat);
                $compat =~ s/[^\d]//g;
                $compat_value = $compat;
                $compatnan = 1;
            }
            if ($level) {
                my $c = $compat;
                $self->tag(
                    'declares-possibly-conflicting-debhelper-compat-versions',
                    "rules=$level compat=${c}"
                );
            } else {
                # this is not just to fill in the gap, but because debhelper
                # prefers DH_COMPAT over debian/compat
                $level = $compat_value;
            }
            $self->tag('uses-debhelper-compat-file')
              if $compat_value >= 11
              and $compat_value < $compat_level->value('experimental');
        } else {
            $self->tag('debhelper-compat-file-is-empty');
        }
    } else {
        $self->tag('debhelper-compat-file-is-missing') unless $compatvirtual;
    }

    if (defined($level) and $level !~ m/^\d+$/ and not $compatnan) {
        $self->tag('debhelper-compatibility-level-not-a-number', $level);
        $level =~ s/[^\d]//g;
        $compatnan = 1;
    }

    $self->tag('debhelper-compat-level', $level) if defined($level);
    $level ||= 1;
    if ($level < $compat_level->value('deprecated')) {
        $self->tag('package-uses-deprecated-debhelper-compat-version', $level);
    } elsif ($level < $compat_level->value('recommended')) {
        $self->tag('package-uses-old-debhelper-compat-version', $level);
    } elsif ($level >= $compat_level->value('experimental')) {
        $self->tag('package-uses-experimental-debhelper-compat-version',
            $level);
    }

    if ($seendhcleank) {
        $self->tag('dh-clean-k-is-deprecated');
    }

    for my $suffix (qw(enable start)) {
        my ($line, $arch) = @{$overrides{"dh_systemd_$suffix"} // []};
        $self->tag(
            'debian-rules-uses-deprecated-systemd-override',
            "override_dh_systemd_$suffix$arch",
            "(line $line)"
        ) if $line and $level >= 11;
    }

    my $num_overrides = scalar(keys %overrides);
    $self->tag('excessive-debhelper-overrides', $num_overrides)
      if $num_overrides >= 20;

    $self->tag(
        'debian-rules-uses-unnecessary-dh-argument',
        'dh ... --parallel',
        "(line $seen_dh_parallel)"
    ) if $seen_dh_parallel and $level >= 10;

    $self->tag(
        'debian-rules-uses-unnecessary-dh-argument',
        "dh ... --with=systemd (line $seen_dh_systemd)"
    ) if $seen_dh_systemd and $level >= 10;

    # Check the files in the debian directory for various debhelper-related
    # things.
    for my $file ($droot->children) {
        next if not $file->is_symlink and not $file->is_file;
        next if $file->name eq $drules->name;
        my $basename = $file->basename;
        if ($basename =~ m/^(?:(.*)\.)?(?:post|pre)(?:inst|rm)$/) {
            next unless $needtomodifyscripts;
            next unless $file->is_open_ok;

            # They need to have #DEBHELPER# in their scripts.  Search
            # for scripts that look like maintainer scripts and make
            # sure the token is there.
            my $binpkg = $1 || '';
            my $seentag = '';
            open(my $fd, '<', $file->unpacked_path);
            while (<$fd>) {
                if (m/\#DEBHELPER\#/) {
                    $seentag = 1;
                    last;
                }
            }
            close($fd);
            if (!$seentag) {
                my $binpkg_type = $processable->binary_package_type($binpkg)
                  // 'deb';
                my $is_udeb = 0;
                $is_udeb = 1 if $binpkg and $binpkg_type eq 'udeb';
                $is_udeb = 1 if not $binpkg and $single_pkg eq 'udeb';
                if (not $is_udeb) {
                    $self->tag('maintainer-script-lacks-debhelper-token',
                        $file);
                }
            }
        } elsif ($basename eq 'control'
            or $basename =~ m/^(?:.*\.)?(?:copyright|changelog|NEWS)$/) {
            # Handle "control", [<pkg>.]copyright, [<pkg>.]changelog
            # and [<pkg>.]NEWS
            $self->tag_if_executable($file);
        } elsif ($basename =~ m/^ex\.|\.ex$/i) {
            $self->tag('dh-make-template-in-source', $file);
        } elsif ($basename =~ m/^(?:(.*)\.)?maintscript$/) {
            next unless $file->is_open_ok;
            open(my $fd, '<', $file->unpacked_path);
            while (<$fd>) {
                if (m/--\s+"\$(?:@|{@})"\s*$/) {
                    $self->tag('maintscript-includes-maint-script-parameters',
                        $basename, "(line $.)");
                }
            }
            close($fd);
        } elsif ($basename =~ m/^(?:.+\.)?debhelper(?:\.log)?$/){
            # The regex matches "debhelper", but debhelper/Dh_Lib does not
            # make those, so skip it.
            if ($basename ne 'debhelper') {
                $self->tag('temporary-debhelper-file', $basename);
            }
        } else {
            my $base = $basename;
            $base =~ s/^.+\.//;

            # Check whether this is a debhelper config file that takes
            # a list of filenames.
            if ($filename_configs->known($base)) {
                next unless $file->is_open_ok;
                if ($level < 9) {
                    # debhelper only use executable files in compat 9
                    $self->tag_if_executable($file);
                } else {
                    # Permissions are not really well defined for
                    # symlinks.  Resolve unconditionally, so we are
                    # certain it is not a symlink.
                    my $actual = $file->resolve_path;
                    if ($actual and $actual->is_executable) {
                        my $cmd = _shebang_cmd($file);
                        unless ($cmd) {
                            $self->tag(
'executable-debhelper-file-without-being-executable',
                                $file
                            );
                        }

                        # Do not make assumptions about the contents of an
                        # executable debhelper file, unless it's a dh-exec
                        # script.
                        if ($cmd =~ /dh-exec/) {
                            $needdhexecbuilddepends = 1;
                            $self->check_dh_exec($cmd, $base, $file);
                        }
                        next;
                    }
                }

                open(my $fd, '<', $file->unpacked_path);
                local $_;
                while (<$fd>) {
                    next if /^\s*$/;
                    next if (/^\#/ and $level >= 5);
                    if (m/((?<!\\)\{(?:[^\s\\\}]*?,)+[^\\\}\s,]*,*\})/) {
                        $self->tag('brace-expansion-in-debhelper-config-file',
                            $file,$1,"(line $.)");
                        last;
                    }
                }
                close($fd);
            }
        }
    }

    $bdepends_noarch = $processable->relation_noarch('Build-Depends-All');
    $bdepends = $processable->relation('Build-Depends-All');
    if ($needbuilddepends) {
        $self->tag('package-uses-debhelper-but-lacks-build-depends')
          unless $bdepends->implies('debhelper')
          or $bdepends->implies('debhelper-compat');
    }
    if ($needdhexecbuilddepends && !$bdepends->implies('dh-exec')) {
        $self->tag('package-uses-dh-exec-but-lacks-build-depends');
    }

    while (my ($dep, $command) = each %missingbdeps) {
        next if $dep eq 'debhelper'; #handled above
        next
          if $level >= 10
          and any { $_ eq $dep } qw(autotools-dev dh-strip-nondeterminism);
        $self->tag('missing-build-dependency-for-dh_-command',
            "$command => $dep")
          unless ($bdepends_noarch->implies($dep));
    }
    while (my ($dep, $addon) = each %missingbdeps_addons) {
        $self->tag('missing-build-dependency-for-dh-addon', "$addon => $dep")
          unless ($bdepends_noarch->implies($dep));

        # As a special case, the python3 addon needs a dependency on
        # dh-python unless the -dev packages are used.
        my $pkg = 'dh-python';
        $self->tag('missing-build-dependency-for-dh-addon',"$addon => $pkg")
          if $addon eq 'python3'
          && $bdepends_noarch->implies($dep)
          && !$bdepends_noarch->implies(
            'python3-dev:any | python3-all-dev:any')
          && !$bdepends_noarch->implies($pkg);
    }

    $dh_bd_version = $level if not defined($dh_bd_version);
    unless ($bdepends->implies("debhelper (>= ${dh_bd_version}~)")
        or $bdepends->implies("debhelper-compat (= ${dh_bd_version})")){
        my $tagname = 'package-needs-versioned-debhelper-build-depends';
        my @extra = ($level);
        $tagname = 'package-lacks-versioned-build-depends-on-debhelper'
          if ($dh_bd_version <= $compat_level->value('pedantic'));
        $self->tag($tagname, @extra);
    }

    if ($level >= 10) {
        for my $pkg (qw(dh-autoreconf autotools-dev)) {
            next if $pkg eq 'autotools-dev' and $uses_autotools_dev_dh;
            $self->tag('useless-autoreconf-build-depends', $pkg)
              if $bdepends->implies($pkg);
        }
    }

    if ($seen_dh and not $seen{'python2'}) {
        my %python_depends;
        for my $binpkg (@pkgs) {
            if ($processable->binary_relation($binpkg, 'all')
                ->implies('${python:Depends}')) {
                $python_depends{$binpkg} = 1;
            }
        }
        if (%python_depends) {
            $self->tag('python-depends-but-no-python-helper',
                sort(keys %python_depends));
        }
    }
    if ($seen_dh and not $seen{'python3'}) {
        my %python3_depends;
        for my $binpkg (@pkgs) {
            if ($processable->binary_relation($binpkg, 'all')
                ->implies('${python3:Depends}')) {
                $python3_depends{$binpkg} = 1;
            }
        }
        if (%python3_depends) {
            $self->tag('python3-depends-but-no-python3-helper',
                sort(keys %python3_depends));
        }
    }

    if ($seen{'sphinxdoc'} and not $seen_dh_dynamic) {
        my $seen_sphinxdoc = 0;
        for my $binpkg (@pkgs) {
            $seen_sphinxdoc = 1
              if $processable->binary_relation($binpkg, 'all')
              ->implies('${sphinxdoc:Depends}');
        }
        $self->tag('sphinxdoc-but-no-sphinxdoc-depends')
          unless $seen_sphinxdoc;
    }

    return;
}

sub tag_if_executable {
    my ($self, $path) = @_;
    # The permissions of symlinks are not really defined, so resolve
    # $path to ensure we are not dealing with a symlink.
    my $actual = $path->resolve_path;
    $self->tag('package-file-is-executable', $path)
      if $actual and $actual->is_executable;
    return;
}

# Perform various checks on a dh-exec file.
sub check_dh_exec {
    my ($self, $cmd, $base, $path) = @_;

    # Only /usr/bin/dh-exec is allowed, even if
    # /usr/lib/dh-exec/dh-exec-subst works too.
    if ($cmd =~ m,/usr/lib/dh-exec/,) {
        $self->tag('dh-exec-private-helper', $path);
    }

    my ($dhe_subst, $dhe_install, $dhe_filter) = (0, 0, 0);
    open(my $fd, '<', $path->unpacked_path);
    while (<$fd>) {
        if (/\$\{([^\}]+)\}/) {
            my $sv = $1;
            $dhe_subst = 1;

            if (
                $sv !~ m{ \A
                   DEB_(?:BUILD|HOST)_(?:
                       ARCH (?: _OS|_CPU|_BITS|_ENDIAN )?
                      |GNU_ (?:CPU|SYSTEM|TYPE)|MULTIARCH
             ) \Z}xsm
            ) {
                $self->tag('dh-exec-subst-unknown-variable', $path, $sv);
            }
        }
        $dhe_install = 1 if /[ \t]=>[ \t]/;
        $dhe_filter = 1 if /\[[^\]]+\]/;
        $dhe_filter = 1 if /<[^>]+>/;

        if (  /^usr\/lib\/\$\{([^\}]+)\}\/?$/
            ||/^usr\/lib\/\$\{([^\}]+)\}\/?\s+\/usr\/lib\/\$\{([^\}]+)\}\/?$/
            ||/^usr\/lib\/\$\{([^\}]+)\}[^\s]+$/) {
            my $sv = $1;
            my $dv = $2;
            my $dhe_useless = 0;

            if (
                $sv =~ m{ \A
                   DEB_(?:BUILD|HOST)_(?:
                       ARCH (?: _OS|_CPU|_BITS|_ENDIAN )?
                      |GNU_ (?:CPU|SYSTEM|TYPE)|MULTIARCH
             ) \Z}xsm
            ) {
                if (defined($dv)) {
                    $dhe_useless = ($sv eq $dv);
                } else {
                    $dhe_useless = 1;
                }
            }
            if ($dhe_useless && $path =~ /debian\/.*(install|manpages)/) {
                my $form = $_;
                chomp($form);
                $form = "\"$form\"";
                $self->tag('dh-exec-useless-usage', $path, $form);
            }
        }
    }
    close($fd);

    if (!($dhe_subst || $dhe_install || $dhe_filter)) {
        $self->tag('dh-exec-script-without-dh-exec-features', $path);
    }

    if ($dhe_install && ($base ne 'install' && $base ne 'manpages')) {
        $self->tag('dh-exec-install-not-allowed-here', $path);
    }

    return;
}

# Return the command after the #! in the file (if any).
# - if there is no command or no #! line, the empty string is returned.
sub _shebang_cmd {
    my ($path) = @_;
    my $magic;
    my $cmd = '';
    open(my $fd, '<', $path->unpacked_path);
    if (read($fd, $magic, 2)) {
        if ($magic eq '#!') {
            $cmd = <$fd>;

            # It is beyond me why anyone would place a lincity data
            # file here...  but if they do, we will handle it
            # correctly.
            $cmd = '' if $cmd =~ /^#!/;

            # trim both ends
            $cmd =~ s/^\s+|\s+$//g;
        }
    }
    close($fd);

    # We are not checking if it is an ELF executable.  While debhelper
    # allows this (i.e. it also checks for <pkg>.<file>.<arch>), it is
    # not cross-compilation safe.  This is because debhelper uses
    # "HOST" (and not "BUILD") arch, despite its documentation and
    # code (incorrectly) suggests it is using "build".
    #
    # Oh yeah, it is also a terrible waste to keep pre-compiled
    # binaries for all architectures in the source as well. :)

    return $cmd;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

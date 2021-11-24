# debhelper -- lintian check script -*- perl -*-

# Copyright © 1999 by Joey Hess
# Copyright © 2016-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Debhelper;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any firstval);
use List::UtilsBy qw(min_by);
use Text::LevenshteinXS qw(distance);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Pointer::Item;
use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $UNDERSCORE => q{_};
const my $HORIZONTAL_BAR => q{|};

const my $ARROW => q{=>};

# If there is no debian/compat file present but cdbs is being used, cdbs will
# create one automatically.  Currently it always uses compatibility level 5.
# It may be better to look at what version of cdbs the package depends on and
# from that derive the compatibility level....
const my $CDBS_COMPAT => 5;

# minimum versions for features
const my $BRACE_EXPANSION => 5;
const my $USES_EXECUTABLE_FILES => 9;
const my $DH_PARALLEL_NOT_NEEDED => 10;
const my $REQUIRES_AUTOTOOLS => 10;
const my $USES_AUTORECONF => 10;
const my $INVOKES_SYSTEMD => 10;
const my $BETTER_SYSTEMD_INTEGRATION => 11;
const my $VERSIONED_PREREQUISITE_AVAILABLE => 11;

const my $LEVENSHTEIN_TOLERANCE => 3;
const my $MANY_OVERRIDES => 20;

my $MISC_DEPENDS = Lintian::Relation->new->load('${misc:Depends}');

# Manually maintained list of dh_commands that requires a versioned
# dependency *AND* are not provided by debhelper.  Commands provided
# by debhelper is handled in checks/debhelper.
#
# This overrules any thing listed in dh_commands (which is auto-generated).

my %DH_COMMAND_MANUAL_PREREQUISITES = (
    dh_apache2 => 'dh-apache2 | apache2-dev',
    dh_autoreconf_clean =>
      'dh-autoreconf | debhelper (>= 9.20160403~) | debhelper-compat',
    dh_autoreconf =>
      'dh-autoreconf | debhelper (>= 9.20160403~) | debhelper-compat',
    dh_dkms => 'dkms | dh-sequence-dkms',
    dh_girepository => 'gobject-introspection | dh-sequence-gir',
    dh_gnome => 'gnome-pkg-tools | dh-sequence-gnome',
    dh_gnome_clean => 'gnome-pkg-tools | dh-sequence-gnome',
    dh_lv2config => 'lv2core',
    dh_make_pgxs => 'postgresql-server-dev-all | postgresql-all',
    dh_nativejava => 'gcj-native-helper | default-jdk-builddep',
    dh_pgxs_test => 'postgresql-server-dev-all | postgresql-all',
    dh_python2 => 'dh-python | dh-sequence-python2',
    dh_python3 => 'dh-python | dh-sequence-python3',
    dh_sphinxdoc => 'sphinx | python-sphinx | python3-sphinx',
    dh_xine => 'libxine-dev | libxine2-dev'
);

# Manually maintained list of dependencies needed for dh addons. This overrides
# information from data/common/dh_addons (the latter file is automatically
# generated).
my %DH_ADDON_MANUAL_PREREQUISITES = (
    ada_library => 'dh-ada-library | dh-sequence-ada-library',
    apache2 => 'dh-apache2 | apache2-dev',
    autoreconf =>
      'dh-autoreconf | debhelper (>= 9.20160403~) | debhelper-compat',
    cli => 'cli-common-dev | dh-sequence-cli',
    dwz => 'debhelper | debhelper-compat | dh-sequence-dwz',
    installinitramfs =>
      'debhelper | debhelper-compat | dh-sequence-installinitramfs',
    gnome => 'gnome-pkg-tools | dh-sequence-gnome',
    lv2config => 'lv2core',
    nodejs => 'pkg-js-tools | dh-sequence-nodejs',
    perl_dbi => 'libdbi-perl | dh-sequence-perl-dbi',
    perl_imager => 'libimager-perl | dh-sequence-perl-imager',
    pgxs => 'postgresql-server-dev-all | postgresql-all',
    pgxs_loop => 'postgresql-server-dev-all | postgresql-all',
    pypy => 'dh-python | dh-sequence-pypy',
    python2 => 'python2:any | python2-dev:any | dh-sequence-python2',
    python3 =>
'python3:any | python3-all:any | python3-dev:any | python3-all-dev:any | dh-sequence-python3',
    scour => 'scour | python-scour | dh-sequence-scour',
    sphinxdoc =>
      'sphinx | python-sphinx | python3-sphinx | dh-sequence-sphinxdoc',
    systemd =>
'debhelper (>= 9.20160709~) | debhelper-compat | dh-sequence-systemd | dh-systemd',
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->dirname eq 'debian/';

    return
      if !$item->is_symlink && !$item->is_file;

    if (   $item->basename eq 'control'
        || $item->basename =~ m/^(?:.*\.)?(?:copyright|changelog|NEWS)$/) {

        # Handle "control", [<pkg>.]copyright, [<pkg>.]changelog
        # and [<pkg>.]NEWS

        # The permissions of symlinks are not really defined, so resolve
        # $item to ensure we are not dealing with a symlink.
        my $actual = $item->resolve_path;

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($item);

        $self->pointed_hint('package-file-is-executable', $pointer)
          if $actual && $actual->is_executable;

        return;
    }

    return;
}

sub source {
    my ($self) = @_;

    my @MAINT_COMMANDS = @{$self->profile->debhelper_commands->maint_commands};

    my $FILENAME_CONFIGS
      = $self->profile->load_data('debhelper/filename-config-files');

    my $DEBHELPER_LEVELS = $self->profile->debhelper_levels;
    my $DH_ADDONS = $self->profile->debhelper_addons;
    my $DH_COMMANDS_DEPENDS= $self->profile->debhelper_commands;

    my @KNOWN_DH_COMMANDS;
    for my $command ($DH_COMMANDS_DEPENDS->all) {
        for my $focus ($EMPTY, qw(-arch -indep)) {
            for my $timing (qw(override execute_before execute_after)) {

                push(@KNOWN_DH_COMMANDS,
                    $timing . $UNDERSCORE . $command . $focus);
            }
        }
    }

    my $debhelper_level;
    my $dh_compat_variable;
    my $maybe_skipping;

    my $uses_debhelper = 0;
    my $uses_dh_exec = 0;
    my $uses_autotools_dev_dh = 0;

    my $includes_cdbs = 0;
    my $modifies_scripts = 0;

    my $seen_any_dh_command = 0;
    my $seen_dh_sequencer = 0;
    my $seen_dh_dynamic = 0;
    my $seen_dh_systemd = 0;
    my $seen_dh_parallel = 0;
    my $seen_dh_clean_k = 0;

    my %command_by_prerequisite;
    my %addon_by_prerequisite;
    my %overrides;

    my $droot = $self->processable->patched->resolve_path('debian/');

    my $drules;
    $drules = $droot->child('rules') if $droot;

    return
      unless $drules && $drules->is_open_ok;

    open(my $rules_fd, '<', $drules->unpacked_path)
      or die encode_utf8('Cannot open ' . $drules->unpacked_path);

    my $command_prefix_pattern = qr/\s+[@+-]?(?:\S+=\S+\s+)*/;

    my $build_prerequisites_norestriction
      = $self->processable->relation_norestriction('Build-Depends-All');
    my $build_prerequisites= $self->processable->relation('Build-Depends-All');

    my %seen = (
        'python2' => 0,
        'python3' => 0,
        'runit'   => 0,
        'sphinxdoc' => 0,
    );

    for (qw(python2 python3)) {

        $seen{$_} = 1
          if $build_prerequisites_norestriction->satisfies("dh-sequence-$_");
    }

    my %build_systems;

    my $position = 1;
    while (my $line = <$rules_fd>) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($drules);
        $pointer->position($position);

        while ($line =~ s/\\$// && defined(my $cont = <$rules_fd>)) {
            $line .= $cont;
        }

        if ($line =~ /^ifn?(?:eq|def)\s/) {
            $maybe_skipping++;

        } elsif ($line =~ /^endif\s/) {
            $maybe_skipping--;
        }

        next
          if $line =~ /^\s*\#/;

        if ($line =~ /^$command_prefix_pattern(dh_(?!autoreconf)\S+)/) {

            my $dh_command = $1;

            $build_systems{'debhelper'} = 1
              unless exists $build_systems{'dh'};

            $self->pointed_hint('dh_installmanpages-is-obsolete',$pointer)
              if $dh_command eq 'dh_installmanpages';

            if (   $dh_command eq 'dh_autotools-dev_restoreconfig'
                || $dh_command eq 'dh_autotools-dev_updateconfig') {

                $self->pointed_hint(
                    'debhelper-tools-from-autotools-dev-are-deprecated',
                    $pointer, $dh_command);
                $uses_autotools_dev_dh = 1;
            }

            # Record if we've seen specific helpers, special-casing
            # "dh_python" as Python 2.x.
            $seen{'python2'} = 1 if $dh_command eq 'dh_python2';
            for my $k (keys %seen) {
                $seen{$k} = 1 if $dh_command eq "dh_$k";
            }

            $seen_dh_clean_k = 1
              if $dh_command eq 'dh_clean'
              && $line =~ /\s+\-k(?:\s+.*)?$/s;

            # if command is passed -n, it does not modify the scripts
            $modifies_scripts = 1
              if (any { $dh_command eq $_ } @MAINT_COMMANDS)
              && $line !~ /\s+\-n\s+/;

           # If debhelper commands are wrapped in make conditionals, assume the
           # maintainer knows what they're doing and don't check build
           # dependencies.
            unless ($maybe_skipping) {

                if (exists $DH_COMMAND_MANUAL_PREREQUISITES{$dh_command}) {
                    my $prerequisite
                      = $DH_COMMAND_MANUAL_PREREQUISITES{$dh_command};
                    $command_by_prerequisite{$prerequisite} = $dh_command;

                } elsif ($DH_COMMANDS_DEPENDS->installed_by($dh_command)) {
                    my $prerequisite = join(
                        $SPACE . $HORIZONTAL_BAR . $SPACE,
                        $DH_COMMANDS_DEPENDS->installed_by($dh_command));
                    $command_by_prerequisite{$prerequisite} = $dh_command;
                }
            }

            $seen_any_dh_command = 1;
            $uses_debhelper = 1;

        } elsif ($line =~ m{^(?:$command_prefix_pattern)dh\s+}) {

            $build_systems{'dh'} = 1;
            delete($build_systems{'debhelper'});

            $seen_dh_sequencer = 1;
            $seen_any_dh_command = 1;

            $seen_dh_dynamic = 1
              if $line =~ /\$[({]\w/;

            $seen_dh_parallel = $position
              if $line =~ /--parallel/;

            $uses_debhelper = 1;
            $modifies_scripts = 1;

            while ($line =~ /\s--with(?:=|\s+)(['"]?)(\S+)\1/g) {

                my $addon_list = $2;

                for my $addon (split(/,/, $addon_list)) {

                    my $orig_addon = $addon;

                    $addon =~ y,-,_,;

                    my $prerequisite = $DH_ADDON_MANUAL_PREREQUISITES{$addon}
                      || join(
                        $SPACE . $HORIZONTAL_BAR . $SPACE,
                        $DH_ADDONS->installed_by($addon));

                    if ($addon eq 'autotools_dev') {

                        $self->pointed_hint(
'debhelper-tools-from-autotools-dev-are-deprecated',
                            $pointer,"dh ... --with $orig_addon"
                        );
                        $uses_autotools_dev_dh = 1;
                    }

                    $seen_dh_systemd = $position
                      if $addon eq 'systemd';

                    $self->pointed_hint(
                        'dh-quilt-addon-but-quilt-source-format',
                        $pointer,"dh ... --with $orig_addon")
                      if $addon eq 'quilt'
                      && $self->processable->fields->value('Format') eq
                      '3.0 (quilt)';

                    $addon_by_prerequisite{$prerequisite} = $addon
                      if defined $prerequisite;

                    for my $k (keys %seen) {
                        $seen{$k} = 1
                          if $addon eq $k;
                    }
                }
            }

        } elsif ($line =~ m{^include\s+/usr/share/cdbs/1/rules/debhelper.mk}
            || $line =~ m{^include\s+/usr/share/R/debian/r-cran.mk}) {

            $build_systems{'cdbs-with-debhelper.mk'} = 1;
            delete($build_systems{'cdbs-without-debhelper.mk'});

            $seen_any_dh_command = 1;
            $uses_debhelper = 1;
            $modifies_scripts = 1;
            $includes_cdbs = 1;

            # CDBS sets DH_COMPAT but doesn't export it.
            $dh_compat_variable = $CDBS_COMPAT;

        } elsif ($line =~ /^\s*export\s+DH_COMPAT\s*:?=\s*([^\s]+)/) {
            $debhelper_level = $1;

        } elsif ($line =~ /^\s*export\s+DH_COMPAT/) {
            $debhelper_level = $dh_compat_variable
              if $dh_compat_variable;

        } elsif ($line =~ /^\s*DH_COMPAT\s*:?=\s*([^\s]+)/) {
            $dh_compat_variable = $1;

            # one can export and then set the value:
            $debhelper_level = $1
              if $debhelper_level;

        } elsif (
            $line =~ /^[^:]*(override|execute_(?:after|before))\s+(dh_[^:]*):/)
        {
            $self->pointed_hint('typo-in-debhelper-override-target',
                $pointer, "$1 $2",$ARROW, "$1_$2");

        } elsif ($line =~ /^([^:]*_dh_[^:]*):/) {

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
                my @near = grep { $distance{$_} < $LEVENSHTEIN_TOLERANCE }
                  keys %distance;
                my $nearest = min_by { $distance{$_} } @near;

                $self->pointed_hint('typo-in-debhelper-override-target',
                    $pointer, $target, $ARROW, $nearest)
                  if length $nearest;
            }

            for my $target (@no_wildcards) {

                next
                  unless $target
                  =~ /^(override|execute_(?:before|after))_dh_([^\s]+?)(-arch|-indep|)$/;

                my $timing = $1;
                my $command = $2;
                my $focus = $3;
                my $dh_command = "dh_$command";

                $overrides{$dh_command} = [$position, $focus];
                $uses_debhelper = 1;

                next
                  if $DH_COMMANDS_DEPENDS->installed_by($dh_command);

                # Unknown command, so check for likely misspellings
                my $missingauto = firstval { "dh_auto_$command" eq $_ }
                $DH_COMMANDS_DEPENDS->all;

                $self->pointed_hint(
                    'typo-in-debhelper-override-target',$pointer,
                    $timing . $UNDERSCORE . $dh_command,$ARROW,
                    $timing . $UNDERSCORE . $missingauto,
                )if length $missingauto;
            }

        } elsif ($line =~ m{^include\s+/usr/share/cdbs/}) {

            $includes_cdbs = 1;

            $build_systems{'cdbs-without-debhelper.mk'} = 1
              unless exists $build_systems{'cdbs-with-debhelper.mk'};

        } elsif (
            $line =~m{
              ^include \s+
                 /usr/share/(?:
                   dh-php/pkg-pecl\.mk
                  |blends-dev/rules
                 )
              }xsm
        ) {
            # All of these indirectly use dh.
            $seen_any_dh_command = 1;
            $build_systems{'dh'} = 1;
            delete($build_systems{'debhelper'});

        } elsif (
            $line =~m{
              ^include \s+
                 /usr/share/pkg-kde-tools/qt-kde-team/\d+/debian-qt-kde\.mk
              }xsm
        ) {

            $includes_cdbs = 1;
            $build_systems{'dhmk'} = 1;
            delete($build_systems{'debhelper'});
        }

    } continue {
        ++$position;
    }

    close $rules_fd;

    # Variables could contain any add-ons; assume we have seen them all
    %seen = map { $_ => 1 } keys %seen
      if $seen_dh_dynamic;

    my $rough_pointer = Lintian::Pointer::Item->new;
    $rough_pointer->item($drules);

    # Okay - d/rules does not include any file in /usr/share/cdbs/
    $self->pointed_hint('unused-build-dependency-on-cdbs', $rough_pointer)
      if $build_prerequisites->satisfies('cdbs')
      && !$includes_cdbs;

    if (%build_systems) {

        my @systems = sort keys %build_systems;
        $self->pointed_hint('debian-build-system', $rough_pointer,
            join(', ', @systems));

    } else {
        $self->pointed_hint('debian-build-system', $rough_pointer, 'other');
    }

    unless ($seen_any_dh_command || $includes_cdbs) {

        $self->pointed_hint('package-does-not-use-debhelper-or-cdbs',
            $rough_pointer);
        return;
    }

    my @installable_names= $self->processable->debian_control->installables;

    for my $installable_name (@installable_names) {

        next
          if $self->processable->debian_control->installable_package_type(
            $installable_name) ne 'deb';

        my $strong
          = $self->processable->binary_relation($installable_name, 'strong');
        my $all= $self->processable->binary_relation($installable_name, 'all');

        $self->hint('debhelper-but-no-misc-depends', $installable_name)
          unless $all->satisfies($MISC_DEPENDS);

        $self->hint('weak-dependency-on-misc-depends', $installable_name)
          if $all->satisfies($MISC_DEPENDS)
          && !$strong->satisfies($MISC_DEPENDS);
    }

    for my $installable ($self->group->get_processables('binary')) {

        my $breaks
          = $self->processable->binary_relation($installable->name, 'Breaks');
        my $strong
          = $self->processable->binary_relation($installable->name, 'strong');

        $self->pointed_hint('package-uses-dh-runit-but-lacks-breaks-substvar',
            $rough_pointer,$installable->name)
          if $seen{'runit'}
          && $strong->satisfies('runit')
          && (any { m{^ etc/sv/ }msx } @{$installable->installed->sorted_list})
          && !$breaks->satisfies('${runit:Breaks}');
    }

    my $virtual_compat;

    $build_prerequisites->visit(
        sub {
            return 0
              unless m{^debhelper-compat \(= (\d+)\)$};

            $virtual_compat = $1;

            return 1;
        },
        Lintian::Relation::VISIT_PRED_FULL
          | Lintian::Relation::VISIT_STOP_FIRST_MATCH
    );

    my $control_pointer = Lintian::Pointer::Item->new;
    $control_pointer->item(
        $self->processable->patched->resolve_path('debian/control'));

    $self->pointed_hint('debhelper-compat-virtual-relation',
        $control_pointer, $virtual_compat)
      if length $virtual_compat;

    # gives precedence to virtual compat
    $debhelper_level = $virtual_compat
      if length $virtual_compat;

    my $compat_file = $droot->child('compat');

    $self->hint('debhelper-compat-file-is-missing')
      unless ($compat_file && $compat_file->is_open_ok)
      || $virtual_compat;

    my $from_compat_file = $self->check_compat_file;

    if (length $debhelper_level && length $from_compat_file) {

        my $compat_pointer = Lintian::Pointer::Item->new;
        $compat_pointer->item($compat_file);

        $self->pointed_hint(
            'declares-possibly-conflicting-debhelper-compat-versions',
            $compat_pointer, $from_compat_file, 'vs elsewhere',
            $debhelper_level);
    }

    # this is not just to fill in the gap, but because debhelper
    # prefers DH_COMPAT over debian/compat
    $debhelper_level ||= $from_compat_file;

    if (length $debhelper_level && $debhelper_level !~ m/^\d+$/) {

        $self->hint('debhelper-compatibility-level-not-a-number',
            $debhelper_level);
        $debhelper_level =~ s/[^\d]//g;
    }

    $self->hint('debhelper-compat-level', $debhelper_level)
      if length $debhelper_level;

    $debhelper_level ||= 1;

    $self->hint('package-uses-deprecated-debhelper-compat-version',
        $debhelper_level)
      if $debhelper_level < $DEBHELPER_LEVELS->value('deprecated');

    $self->hint('package-uses-old-debhelper-compat-version', $debhelper_level)
      if $debhelper_level >= $DEBHELPER_LEVELS->value('deprecated')
      && $debhelper_level < $DEBHELPER_LEVELS->value('recommended');

    $self->hint('package-uses-experimental-debhelper-compat-version',
        $debhelper_level)
      if $debhelper_level >= $DEBHELPER_LEVELS->value('experimental');

    $self->pointed_hint('dh-clean-k-is-deprecated', $rough_pointer)
      if $seen_dh_clean_k;

    for my $suffix (qw(enable start)) {

        my ($stored_position, $focus)
          = @{$overrides{"dh_systemd_$suffix"} // []};

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($drules);
        $pointer->position($stored_position);

        $self->pointed_hint('debian-rules-uses-deprecated-systemd-override',
            $pointer,"override_dh_systemd_$suffix$focus")
          if $stored_position
          && $debhelper_level >= $BETTER_SYSTEMD_INTEGRATION;
    }

    my $num_overrides = scalar(keys %overrides);

    $self->hint('excessive-debhelper-overrides', $num_overrides)
      if $num_overrides >= $MANY_OVERRIDES;

    if ($seen_dh_parallel && $debhelper_level >= $DH_PARALLEL_NOT_NEEDED) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($drules);
        $pointer->position($seen_dh_parallel);

        $self->pointed_hint('debian-rules-uses-unnecessary-dh-argument',
            $pointer,'dh ... --parallel');
    }

    if ($seen_dh_systemd && $debhelper_level >= $INVOKES_SYSTEMD) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($drules);
        $pointer->position($seen_dh_systemd);

        $self->pointed_hint('debian-rules-uses-unnecessary-dh-argument',
            $pointer,'dh ... --with=systemd');
    }

    for my $item ($droot->children) {

        next
          if !$item->is_symlink && !$item->is_file;

        next
          if $item->name eq $drules->name;

        if ($item->basename =~ m/^(?:(.*)\.)?(?:post|pre)(?:inst|rm)$/) {

            next
              unless $modifies_scripts;

            # They need to have #DEBHELPER# in their scripts.  Search
            # for scripts that look like maintainer scripts and make
            # sure the token is there.
            my $installable_name = $1 || $EMPTY;
            my $seentag = 0;

            $seentag = 1
              if $item->decoded_utf8 =~ /\#DEBHELPER\#/;

            if (!$seentag) {

                my $single_pkg = $EMPTY;
                $single_pkg
                  =  $self->processable->debian_control
                  ->installable_package_type($installable_names[0])
                  if scalar @installable_names == 1;

                my $installable_type
                  = $self->processable->debian_control
                  ->installable_package_type($installable_name);

                my $is_udeb = 0;

                $is_udeb = 1
                  if $installable_name && $installable_type eq 'udeb';

                $is_udeb = 1
                  if !$installable_name && $single_pkg eq 'udeb';

                my $pointer = Lintian::Pointer::Item->new;
                $pointer->item($item);

                $self->pointed_hint('maintainer-script-lacks-debhelper-token',
                    $pointer)
                  unless $is_udeb;
            }

            next;
        }

        my $category = $item->basename;
        $category =~ s/^.+\.//;

        next
          unless length $category;

        # Check whether this is a debhelper config file that takes
        # a list of filenames.
        if ($FILENAME_CONFIGS->recognizes($category)) {

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($item);

            # The permissions of symlinks are not really defined, so resolve
            # $item to ensure we are not dealing with a symlink.
            my $actual = $item->resolve_path;
            next
              unless defined $actual;

            $self->check_for_brace_expansion($item, $debhelper_level);

            # debhelper only use executable files in compat 9
            $self->pointed_hint('package-file-is-executable', $pointer)
              if $actual->is_executable
              && $debhelper_level < $USES_EXECUTABLE_FILES;

            if ($debhelper_level >= $USES_EXECUTABLE_FILES) {

                $self->pointed_hint(
                    'executable-debhelper-file-without-being-executable',
                    $pointer)
                  if $actual->is_executable
                  && !length $actual->hashbang;

                # Only /usr/bin/dh-exec is allowed, even if
                # /usr/lib/dh-exec/dh-exec-subst works too.
                $self->pointed_hint('dh-exec-private-helper', $pointer)
                  if $actual->is_executable
                  && $actual->hashbang =~ m{^/usr/lib/dh-exec/};

                # Do not make assumptions about the contents of an
                # executable debhelper file, unless it's a dh-exec
                # script.
                if ($actual->hashbang =~ /dh-exec/) {

                    $uses_dh_exec = 1;
                    $self->check_dh_exec($item, $category);
                }
            }
        }
    }

    $self->pointed_hint('package-uses-debhelper-but-lacks-build-depends',
        $rough_pointer)
      if $uses_debhelper
      && !$build_prerequisites->satisfies('debhelper')
      && !$build_prerequisites->satisfies('debhelper-compat');

    $self->pointed_hint('package-uses-dh-exec-but-lacks-build-depends',
        $rough_pointer)
      if $uses_dh_exec
      && !$build_prerequisites->satisfies('dh-exec');

    for my $prerequisite (keys %command_by_prerequisite) {

        my $command = $command_by_prerequisite{$prerequisite};

        # handled above
        next
          if $prerequisite eq 'debhelper';

        next
          if $debhelper_level >= $REQUIRES_AUTOTOOLS
          && (
            any { $_ eq $prerequisite }
            qw(autotools-dev dh-strip-nondeterminism)
          );

        $self->pointed_hint('missing-build-dependency-for-dh_-command',
            $rough_pointer,$command, $ARROW, $prerequisite)
          unless $build_prerequisites_norestriction->satisfies($prerequisite);
    }

    for my $prerequisite (keys %addon_by_prerequisite) {

        my $addon = $addon_by_prerequisite{$prerequisite};

        $self->pointed_hint('missing-build-dependency-for-dh-addon',
            $rough_pointer,$addon, $ARROW, $prerequisite)
          unless (
            $build_prerequisites_norestriction->satisfies($prerequisite));

        # As a special case, the python3 addon needs a dependency on
        # dh-python unless the -dev packages are used.
        my $python_source = 'dh-python';

        $self->pointed_hint('missing-build-dependency-for-dh-addon',
            $rough_pointer,$addon, $ARROW, $python_source)
          if $addon eq 'python3'
          && $build_prerequisites_norestriction->satisfies($prerequisite)
          && !$build_prerequisites_norestriction->satisfies(
            'python3-dev:any | python3-all-dev:any')
          && !$build_prerequisites_norestriction->satisfies($python_source);
    }

    $self->hint('no-versioned-debhelper-prerequisite', $debhelper_level)
      unless $build_prerequisites->satisfies(
        "debhelper (>= $debhelper_level~)")
      || $build_prerequisites->satisfies(
        "debhelper-compat (= $debhelper_level)");

    if ($debhelper_level >= $USES_AUTORECONF) {
        for my $autotools_source (qw(dh-autoreconf autotools-dev)) {

            next
              if $autotools_source eq 'autotools-dev'
              && $uses_autotools_dev_dh;

            $self->hint('useless-autoreconf-build-depends',$autotools_source)
              if $build_prerequisites->satisfies($autotools_source);
        }
    }

    if ($seen_dh_sequencer && !$seen{'python2'}) {

        my %python_depends;

        for my $installable_name (@installable_names) {

            $python_depends{$installable_name} = 1
              if $self->processable->binary_relation($installable_name,'all')
              ->satisfies('${python:Depends}');
        }

        $self->hint('python-depends-but-no-python-helper',
            (sort keys %python_depends))
          if %python_depends;
    }

    if ($seen_dh_sequencer && !$seen{'python3'}) {

        my %python3_depends;

        for my $installable_name (@installable_names) {

            $python3_depends{$installable_name} = 1
              if $self->processable->binary_relation($installable_name,'all')
              ->satisfies('${python3:Depends}');
        }

        $self->hint('python3-depends-but-no-python3-helper',
            (sort keys %python3_depends))
          if %python3_depends;
    }

    if ($seen{'sphinxdoc'} && !$seen_dh_dynamic) {

        my $seen_sphinxdoc = 0;

        for my $installable_name (@installable_names) {
            $seen_sphinxdoc = 1
              if $self->processable->binary_relation($installable_name,'all')
              ->satisfies('${sphinxdoc:Depends}');
        }

        $self->pointed_hint('sphinxdoc-but-no-sphinxdoc-depends',
            $rough_pointer)
          unless $seen_sphinxdoc;
    }

    return;
}

sub check_for_brace_expansion {
    my ($self, $item, $debhelper_level) = @_;

    return
      unless $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        next
          if $line =~ /^\s*$/;

        next
          if $line =~ /^\#/
          && $debhelper_level >= $BRACE_EXPANSION;

        if ($line =~ /((?<!\\)\{(?:[^\s\\\}]*?,)+[^\\\}\s,]*,*\})/){
            my $expansion = $1;

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($item);
            $pointer->position($position);

            $self->pointed_hint('brace-expansion-in-debhelper-config-file',
                $pointer, $expansion);

            last;
        }

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

sub check_compat_file {
    my ($self) = @_;

    # Check the compat file.  Do this separately from looping over all
    # of the other files since we use the compat value when checking
    # for brace expansion.

    my $compat_file
      = $self->processable->patched->resolve_path('debian/compat');

    # missing file is dealt with elsewhere
    return $EMPTY
      unless $compat_file && $compat_file->is_open_ok;

    my $debhelper_level;

    open(my $fd, '<', $compat_file->unpacked_path)
      or die encode_utf8('Cannot open ' . $compat_file->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        if ($position == 1) {

            $debhelper_level = $line;
            next;
        }

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($compat_file);
        $pointer->position($position);

        $self->pointed_hint('debhelper-compat-file-contains-multiple-levels',
            $pointer)
          if $line =~ /^\d/;

    } continue {
        ++$position;
    }

    close $fd;

    # trim both ends
    $debhelper_level =~ s/^\s+|\s+$//g;

    if (!length $debhelper_level) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($compat_file);

        $self->pointed_hint('debhelper-compat-file-is-empty', $pointer);
        return $EMPTY;
    }

    my $DEBHELPER_LEVELS = $self->profile->debhelper_levels;

    my $compat_pointer = Lintian::Pointer::Item->new;
    $compat_pointer->item($compat_file);

    # Recommend people use debhelper-compat (introduced in debhelper
    # 11.1.5~alpha1) over debian/compat, except for experimental/beta
    # versions.
    $self->pointed_hint('uses-debhelper-compat-file', $compat_pointer)
      if $debhelper_level >= $VERSIONED_PREREQUISITE_AVAILABLE
      && $debhelper_level < $DEBHELPER_LEVELS->value('experimental');

    return $debhelper_level;
}

sub check_dh_exec {
    my ($self, $item, $category) = @_;

    return
      unless $item->is_open_ok;

    my $dhe_subst = 0;
    my $dhe_install = 0;
    my $dhe_filter = 0;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        chomp $line;

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($item);
        $pointer->position($position);

        if ($line =~ /\$\{([^\}]+)\}/) {

            my $sv = $1;
            $dhe_subst = 1;

            if (
                $sv !~ m{ \A
                   DEB_(?:BUILD|HOST)_(?:
                       ARCH (?: _OS|_CPU|_BITS|_ENDIAN )?
                      |GNU_ (?:CPU|SYSTEM|TYPE)|MULTIARCH
             ) \Z}xsm
            ) {
                $self->pointed_hint('dh-exec-subst-unknown-variable',
                    $pointer, $sv);
            }
        }

        $dhe_install = 1
          if $line =~ /[ \t]=>[ \t]/;

        $dhe_filter = 1
          if $line =~ /\[[^\]]+\]/;

        $dhe_filter = 1
          if $line =~ /<[^>]+>/;

        if (   $line =~ /^usr\/lib\/\$\{([^\}]+)\}\/?$/
            || $line
            =~ /^usr\/lib\/\$\{([^\}]+)\}\/?\s+\/usr\/lib\/\$\{([^\}]+)\}\/?$/
            || $line =~ /^usr\/lib\/\$\{([^\}]+)\}[^\s]+$/) {

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

            $self->pointed_hint('dh-exec-useless-usage', $pointer, $line)
              if $dhe_useless && $item =~ /debian\/.*(install|manpages)/;
        }

    } continue {
        ++$position;
    }

    close $fd;

    my $rough_pointer = Lintian::Pointer::Item->new;
    $rough_pointer->item($item);

    $self->pointed_hint('dh-exec-script-without-dh-exec-features',
        $rough_pointer)
      if !$dhe_subst
      && !$dhe_install
      && !$dhe_filter;

    $self->pointed_hint('dh-exec-install-not-allowed-here', $rough_pointer)
      if $dhe_install
      && $category ne 'install'
      && $category ne 'manpages';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

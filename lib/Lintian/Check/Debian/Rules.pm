# debian/rules -- lintian check script -*- perl -*-

# Copyright © 2006 Russ Allbery <rra@debian.org>
# Copyright © 2005 René van Bevern <rvb@pro-linux.de>
# Copyright © 2019-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Debian::Rules;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any none uniq);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $PERCENT => q{%};

my @py3versions = qw(3.4 3.5 3.6 3.7);

my $PYTHON_DEPEND= 'python2:any | python2-dev:any';
my $PYTHON3_DEPEND
  = 'python3:any | python3-dev:any | python3-all:any | python3-all-dev:any';
my $PYTHON2X_DEPEND = 'python2.7:any | python2.7-dev:any';
my $PYTHON3X_DEPEND
  = join(' | ',map { "python${_}:any | python${_}-dev:any" } @py3versions);
my $ANYPYTHON_DEPEND
  = "$PYTHON_DEPEND | $PYTHON2X_DEPEND | $PYTHON3_DEPEND | $PYTHON3X_DEPEND";
my $PYTHON3_ALL_DEPEND
  = 'python3-all:any | python3-all-dev:any | python3-all-dbg:any';

my %TAG_FOR_POLICY_TARGET = (
    build => 'debian-rules-missing-required-target',
    binary => 'debian-rules-missing-required-target',
    'binary-arch' => 'debian-rules-missing-required-target',
    'binary-indep' => 'debian-rules-missing-required-target',
    clean => 'debian-rules-missing-required-target',
    'build-arch' => 'debian-rules-missing-recommended-target',
    'build-indep' => 'debian-rules-missing-recommended-target'
);

# Rules about required debhelper command ordering.  Each command is put into a
# class and the tag is issued if they're called in the wrong order for the
# classes.  Unknown commands won't trigger this flag.
my %debhelper_order = (
    dh_makeshlibs => 1,
    dh_shlibdeps  => 2,
    dh_installdeb => 2,
    dh_gencontrol => 2,
    dh_builddeb   => 3
);

sub source {
    my ($self) = @_;

    my $debian_dir = $self->processable->patched->resolve_path('debian');

    my $rules;
    $rules = $debian_dir->child('rules')
      if defined $debian_dir;

    return
      unless defined $rules;

    # Policy could be read as allowing debian/rules to be a symlink to
    # some other file, and in a native Debian package it could be a
    # symlink to a file that we didn't unpack.
    $self->hint('debian-rules-is-symlink')
      if $rules->is_symlink;

    # dereference symbolic links
    $rules = $rules->follow;

    return
      unless defined $rules;

    $self->hint('debian-rules-not-executable') unless $rules->is_executable;

    my $KNOWN_MAKEFILES
      = $self->profile->load_data('rules/known-makefiles', '\|\|');
    my $DEPRECATED_MAKEFILES
      = $self->profile->load_data('rules/deprecated-makefiles');

    my $architecture = $self->processable->fields->value('Architecture');

    # If the version field is missing, we assume a neutral non-native one.
    my $version = $self->processable->fields->value('Version') || '0-1';

    # Check for required #!/usr/bin/make -f opening line.  Allow -r or -e; a
    # strict reading of Policy doesn't allow either, but they seem harmless.
    $self->hint('debian-rules-not-a-makefile')
      unless $rules->hashbang =~ m{^/usr/bin/make\s+-[re]?f[re]?$};

   # Certain build tools must be listed in Build-Depends even if there are no
   # arch-specific packages because they're required in order to run the clean
   # rule.  (See Policy 7.6.)  The following is a list of package dependencies;
   # regular expressions that, if they match anywhere in the debian/rules file,
   # say that this package is allowed (and required) in Build-Depends; and
   # optional tags to use for reporting the problem if some information other
   # than the default is required.
    my %GLOBAL_CLEAN_DEPENDS = (
        ant => [qr{^include\s*/usr/share/cdbs/1/rules/ant\.mk}],
        cdbs => [
            qr{^include\s+/usr/share/cdbs/},
            qr{^include\s+/usr/share/R/debian/r-cran\.mk}
        ],
        dbs => [qr{^include\s+/usr/share/dbs/}],
        'dh-make-php' => [qr{^include\s+/usr/share/cdbs/1/class/pear\.mk}],
        'debhelper | debhelper-compat' =>[
            qr{^include\s+/usr/share/cdbs/1/rules/debhelper\.mk},
            qr{^include\s+/usr/share/R/debian/r-cran\.mk}
        ],
        dpatch => [
            qr{^include\s+/usr/share/dpatch/},
            qr{^include\s+/usr/share/cdbs/1/rules/dpatch\.mk}
        ],
        'gnome-pkg-tools | dh-sequence-gnome' =>
          [qr{^include\s+/usr/share/gnome-pkg-tools/}],
        quilt => [
            qr{^include\s+/usr/share/quilt/},
            qr{^include\s+/usr/share/cdbs/1/rules/patchsys-quilt\.mk}
        ],
        'mozilla-devscripts' =>[qr{^include\s+/usr/share/mozilla-devscripts/}],
        'ruby-pkg-tools' =>[qr{^include\s+/usr/share/ruby-pkg-tools/1/class/}],
        'r-base-dev' => [qr{^include\s+/usr/share/R/debian/r-cran\.mk}],
        $ANYPYTHON_DEPEND =>[qr{/usr/share/cdbs/1/class/python-distutils\.mk}],
    );

  # A list of packages; regular expressions that, if they match anywhere in the
  # debian/rules file, this package must be listed in either Build-Depends or
  # Build-Depends-Indep as appropriate; and optional tags as above.
    my %GLOBAL_DEPENDS = (
        'dh-ocaml, ocaml-nox | ocaml' => [qr/^\t\s*dh_ocaml(?:init|doc)\s/],
        'debhelper | debhelper-compat | dh-autoreconf' =>
          [qr/^\t\s*dh_autoreconf(?:_clean)?\s/],
    );

 # Similarly, this list of packages, regexes, and optional tags say that if the
 # regex matches in one of clean, build-arch, binary-arch, or a rule they
 # depend on, this package is allowed (and required) in Build-Depends.
    my %RULE_CLEAN_DEPENDS =(
        ant => [qr/^\t\s*(\S+=\S+\s+)*ant\s/],
        'debhelper | debhelper-compat' => [qr/^\t\s*dh_(?!autoreconf).+/],
        'dh-ocaml, ocaml-nox | ocaml' => [qr/^\t\s*dh_ocamlinit\s/],
        dpatch => [qr/^\t\s*(\S+=\S+\s+)*dpatch\s/],
        'po-debconf' => [qr/^\t\s*debconf-updatepo\s/],
        $PYTHON_DEPEND => [qr/^\t\s*python\s/],
        $PYTHON3_DEPEND => [qr/^\t\s*python3\s/],
        $ANYPYTHON_DEPEND => [qr/\ssetup\.py\b/],
        quilt => [qr/^\t\s*(\S+=\S+\s+)*quilt\s/],
    );

    my $build_all = $self->processable->relation('Build-Depends-All');
    my $build_all_norestriction
      = $self->processable->relation_norestriction('Build-Depends-All');
    my $build_regular = $self->processable->relation('Build-Depends');
    my $build_indep   = $self->processable->relation('Build-Depends-Indep');

    # no need to look for items we have
    delete %GLOBAL_DEPENDS{$_}
      for grep { $build_regular->satisfies($_) } keys %GLOBAL_DEPENDS;
    delete %GLOBAL_CLEAN_DEPENDS{$_}
      for grep { $build_regular->satisfies($_) } keys %GLOBAL_CLEAN_DEPENDS;
    delete %RULE_CLEAN_DEPENDS{$_}
      for grep { $build_regular->satisfies($_) } keys %RULE_CLEAN_DEPENDS;

    my @needed;
    my @needed_clean;

    # Scan debian/rules.  We would really like to let make do this for
    # us, but unfortunately there doesn't seem to be a way to get make
    # to syntax-check and analyze a makefile without running at least
    # $(shell) commands.
    #
    # We skip some of the rule analysis if debian/rules includes any
    # other files, since to chase all includes we'd have to have all
    # of its build dependencies installed.
    local $_ = undef;

    my @arch_rules = map { qr/^$_$/ } qw(clean binary-arch build-arch);
    my @indep_rules = qw(build build-indep binary-indep);
    my @current_targets;
    my %rules_per_target;
    my %debhelper_group;
    my %seen;
    my %overridden;
    my $maybe_skipping;
    my @conditionals;
    my %variables;
    my $includes = 0;

    my $contents = $rules->decoded_utf8;
    return
      unless length $contents;

    my @lines = split(/\n/, $contents);

    my $continued = $EMPTY;
    my $position = 1;

    for my $line (@lines) {

        $self->hint('debian-rules-is-dh_make-template')
          if $line =~ m/dh_make generated override targets/;

        next
          if $line =~ /^\s*\#/;

        if (length $continued) {
            $line = $continued . $line;
            $continued = $EMPTY;
        }

        if ($line =~ s/\\$//) {
            $continued = $line;
            next;
        }

        if ($line =~ /^\s*[s-]?include\s+(\S++)/){
            my $makefile = $1;
            my $targets = $KNOWN_MAKEFILES->value($makefile);
            if (defined $targets){
                for my $target (split /\s*+,\s*+/, $targets){
                    $seen{$target}++ if exists $TAG_FOR_POLICY_TARGET{$target};
                }
            } else {
                $includes = 1;
            }

            $self->hint('debian-rules-uses-deprecated-makefile',
                "(line $position)",$makefile)
              if $DEPRECATED_MAKEFILES->recognizes($makefile);
        }

        # problems occurring only outside targets
        unless (%seen) {

          # Check for DH_COMPAT settings outside of any rule, which are now
          # deprecated.  It's a bit easier structurally to do this here than in
          # debhelper.
            $self->hint('debian-rules-sets-DH_COMPAT', "(line $position)")
              if $line =~ /^\s*(?:export\s+)?DH_COMPAT\s*:?=/;

            $self->hint('debian-rules-sets-DEB_BUILD_OPTIONS',
                "(line $position)")
              if $line =~ /^\s*(?:export\s+)?DEB_BUILD_OPTIONS\s*:?=/;

            if (
                $line =~m{^
                \s*(?:export\s+)?
                (DEB_(?:HOST|BUILD|TARGET)_(?:ARCH|MULTIARCH|GNU)[A-Z_]*)\s*:?=
            }x
            ) {
                $self->hint('debian-rules-sets-dpkg-architecture-variable',
                    "$1 (line $position)");
            }

        }

        if (   $line =~ /^\t\s*-(?:\$[\(\{]MAKE[\}\)]|make)\s.*(?:dist)?clean/s
            || $line
            =~ /^\t\s*(?:\$[\(\{]MAKE[\}\)]|make)\s(?:.*\s)?-(\w*)i.*(?:dist)?clean/s
        ) {
            my $flags = $1 // $EMPTY;

            # Ignore "-C<dir>" (#671537)
            $self->hint('debian-rules-ignores-make-clean-error',
                "(line $position)")
              unless $flags =~ /^C/;
        }

        if ($line
            =~ m{dh_strip\b.*(--(?:ddeb|dbgsym)-migration=(?:'[^']*'|\S*))}) {
            $self->hint('debug-symbol-migration-possibly-complete',
                $1, "(line $position)");
        }

        $self->hint('debian-rules-passes-version-info-to-dh_shlibdeps',
            "(line $position)")
          if $line =~ m{dh_shlibdeps\b.*(?:--version-info|-V)\b};

        $self->hint('debian-rules-updates-control-automatically',
            "(line $position)")
          if $line =~ m{^\s*DEB_AUTO_UPDATE_DEBIAN_CONTROL\s*=\s*yes};

        $self->hint('debian-rules-uses-deb-build-opts', "(line $position)")
          if $line =~ m{\$[\(\{]DEB_BUILD_OPTS[\)\}]};

        if ($line =~ m{^\s*DH_EXTRA_ADDONS\s*=\s*(.*)$}) {
            $self->hint('debian-rules-should-not-use-DH_EXTRA_ADDONS',
                $1, "(line $position)");
        }

        $self->hint('debian-rules-uses-wrong-environment-variable',
            "(line $position)")
          if $line =~ m{\bDEB_[^_ \t]+FLAGS_(?:SET|APPEND)\b};

        $self->hint('debian-rules-calls-pwd', "(line $position)")
          if $line =~ m{\$[\(\{]PWD[\)\}]};

        $self->hint('debian-rules-should-not-use-sanitize-all-buildflag',
            "(line $position)")
          if $line
          =~ m{^\s*(?:export\s+)?DEB_BUILD_MAINT_OPTIONS\s*:?=.*\bsanitize=\+all\b};

        $self->hint('debian-rules-uses-special-shell-variable',
            "(line $position)")
          if $line =~ m{\$[\(\{]_[\)\}]};

        if ($line =~ m{(dh_builddeb\b.*--.*-[zZS].*)$}) {
            $self->hint('custom-compression-in-debian-rules',
                $1, "(line $position)");
        }

        if ($line =~ m{(py3versions\s+([\w\-\s]*--installed|-\w*i\w*))}) {
            $self->hint('debian-rules-uses-installed-python-versions',
                $1, "(line $position)");
        }

        $self->hint('debian-rules-uses-as-needed-linker-flag',
            "(line $position)")
          if $line =~ /--as-needed/ && $line !~ /--no-as-needed/;

        $self->hint(
'debian-rules-uses-supported-python-versions-without-python-all-build-depends',
            $1,
            "(line $position)"
          )
          if $line =~ /(py3versions\s+([\w\-\s]*--supported|-\w*s\w*))/
          && !$build_all_norestriction->satisfies($PYTHON3_ALL_DEPEND);

        # General assignment - save the variable
        if ($line =~ /^\s*(?:\S+\s+)*?(\S+)\s*[:\?\+]?=\s*(.*+)?$/s) {
            # This is far too simple from a theoretical PoV, but should do
            # rather well.
            my ($var, $value) = ($1, $2);
            $variables{$var} = $value;
            $self->hint('unnecessary-source-date-epoch-assignment',
                "(line $position)")
              if $var eq 'SOURCE_DATE_EPOCH'
              and not $build_all->satisfies(
                'dpkg-dev (>= 1.18.8) | debhelper (>= 10.10)');
        }

        # Keep track of whether this portion of debian/rules may be optional
        if ($line =~ /^ifn?(?:eq|def)\s(.*)/) {
            push(@conditionals, $1);
            $maybe_skipping++;

        } elsif ($line =~ /^endif\s/) {
            $maybe_skipping--;
        }

        unless ($maybe_skipping) {

            for my $prerequisite (keys %GLOBAL_DEPENDS) {

                my @patterns = @{ $GLOBAL_DEPENDS{$prerequisite} };

                push(@needed, $prerequisite)
                  if any { $line =~ $_ } @patterns;
            }

            for my $prerequisite (keys %GLOBAL_CLEAN_DEPENDS) {

                my @patterns = @{ $GLOBAL_CLEAN_DEPENDS{$prerequisite} };

                if (any { $line =~ $_ } @patterns) {

                    push(@needed, $prerequisite);
                    push(@needed_clean, $prerequisite);
                }
            }
        }

        # Listing a rule as a dependency of .PHONY is sufficient to make it
        # present for the purposes of GNU make and therefore the Policy
        # requirement.
        if ($line =~ /^(?:[^:]+\s)?\.PHONY(?:\s[^:]+)?:(.+)/s) {

            my @targets = split($SPACE, $1);
            for my $target (@targets) {
                # Is it $(VAR) ?
                if ($target =~ /^\$[\(\{]([^\)\}]++)[\)\}]$/) {
                    my $name = $1;
                    my $val = $variables{$name};
                    if ($val) {
                        # we think we know what it will expand to - note
                        # we ought to "delay" it was a "=" variable rather
                        # than ":=" or "+=".

                   # discards empty elements at end, effectively trimming right
                        for (split(/\s+/, $val)) {
                            $seen{$target}++
                              if exists $TAG_FOR_POLICY_TARGET{$target};
                        }
                        last;
                    }
                    # We don't know, so just mark the target as seen.
                }
                $seen{$target}++
                  if exists $TAG_FOR_POLICY_TARGET{$target};
            }

            #.PHONY implies the rest will not match
            next;
        }

        if (  !$includes
            && $line
            =~ /dpkg-parsechangelog.*(?:Source|Version|Date|Timestamp)/s) {
            $self->hint('debian-rules-parses-dpkg-parsechangelog',
                "(line $position)");
        }

        if ($line !~ /^ifn?(?:eq|def)\s/ && $line =~ /^([^\s:][^:]*):+(.*)/s) {
            my ($target_names, $target_dependencies) = ($1, $2);
            @current_targets = split $SPACE, $target_names;

            my @quoted = map { quotemeta } split($SPACE, $target_dependencies);
            s/\\\$\\\([^\):]+\\:([^=]+)\\=([^\)]+)\1\\\)/$2.*/g for @quoted;

            my @depends = map { qr/^$_$/ } @quoted;

            for my $target (@current_targets) {
                $overridden{$1} = $position if $target =~ m/override_(.+)/;
                if ($target =~ /%/) {
                    my $pattern = quotemeta $target;
                    $pattern =~ s/\\%/.*/g;
                    for my $rulebypolicy (keys %TAG_FOR_POLICY_TARGET) {
                        $seen{$rulebypolicy}++ if $rulebypolicy =~ m/$pattern/;
                    }
                } else {
                    # Is it $(VAR) ?
                    if ($target =~ m/^\$[\(\{]([^\)\}]++)[\)\}]$/) {
                        my $name = $1;
                        my $val = $variables{$name};
                        if ($val) {
                            # we think we know what it will expand to - note
                            # we ought to "delay" it was a "=" variable rather
                            # than ":=" or "+=".
                            local $_ = undef;

                   # discards empty elements at end, effectively trimming right
                            for (split(/\s+/, $val)) {
                                $seen{$_}++
                                  if exists $TAG_FOR_POLICY_TARGET{$_};
                            }
                            last;
                        }
                        # We don't know, so just mark the target as seen.
                    }
                    $seen{$target}++ if exists $TAG_FOR_POLICY_TARGET{$target};
                }
                if (any { $target =~ /$_/ } @arch_rules) {
                    push(@arch_rules, @depends);
                }
            }
            undef %debhelper_group;

        } elsif ($line =~ /^define /) {
            # We don't want to think the body of the define is part of
            # the previous rule or we'll get false positives on tags
            # like binary-arch-rules-but-pkg-is-arch-indep.  Treat a
            # define as the end of the current rule, although that
            # isn't very accurate either.
            @current_targets = ();

        } else {
            # If we have non-empty, non-comment lines, store them for
            # all current targets and check whether debhelper programs
            # are called in a reasonable order.
            if ($line =~ /^\s+[^\#]/) {
                my ($arch, $indep) = (0, 0);
                for my $target (@current_targets) {
                    $rules_per_target{$target} ||= [];
                    push(@{$rules_per_target{$target}}, $line);

                    $arch = 1
                      if any { $target =~ /$_/ } @arch_rules;

                    $indep = 1
                      if any { $target eq $_ } @indep_rules;

                    $indep = 1
                      if $target eq $PERCENT;

                    $indep = 1
                      if $target =~ /^override_/;
                }

                if (!$maybe_skipping && ($arch || $indep)) {

                    for my $prerequisite (keys %RULE_CLEAN_DEPENDS) {

                        my @patterns = @{ $RULE_CLEAN_DEPENDS{$prerequisite} };

                        if (any { $line =~ $_ } @patterns) {

                            push(@needed, $prerequisite);
                            push(@needed_clean, $prerequisite)
                              if $arch;
                        }
                    }
                }

                if ($line =~ /^\s+(dh_\S+)\b/ && $debhelper_order{$1}) {
                    my $command = $1;
                    my ($package) = ($line =~ /\s(?:-p|--package=)(\S+)/);
                    $package ||= $EMPTY;
                    my $group = $debhelper_order{$command};
                    $debhelper_group{$package} ||= 0;

                    if ($group < $debhelper_group{$package}) {
                        $self->hint(
                            'debian-rules-calls-debhelper-in-odd-order',
                            $command, "(line $position)");

                    } else {
                        $debhelper_group{$package} = $group;
                    }
                }
            }
        }

    } continue {
        ++$position;
    }

    my @missing_targets;
    @missing_targets = grep { !$seen{$_} } keys %TAG_FOR_POLICY_TARGET
      unless $includes;

    $self->hint($TAG_FOR_POLICY_TARGET{$_}, $_) for @missing_targets;

    # Make sure we have no content for binary-arch if we are arch-indep:
    $rules_per_target{'binary-arch'} ||= [];
    if ($architecture eq 'all' && scalar @{$rules_per_target{'binary-arch'}}) {

        my $nonempty = 0;
        for my $rule (@{$rules_per_target{'binary-arch'}}) {
            # dh binary-arch is actually a no-op if there is no
            # Architecture: any package in the control file
            $nonempty = 1
              unless $rule =~ /^\s*dh\s+(?:binary-arch|\$\@)/;
        }

        $self->hint('binary-arch-rules-but-pkg-is-arch-indep') if $nonempty;
    }

    for my $cmd (qw(dh_clean dh_fixperms)) {
        for my $suffix ($EMPTY, '-indep', '-arch') {
            my $pointer = $overridden{"$cmd$suffix"};
            $self->hint("override_$cmd-does-not-call-$cmd", "(line $pointer)")
              if $pointer
              and none { m/^\t\s*-?($cmd\b|\$\(overridden_command\))/ }
            @{$rules_per_target{"override_$cmd$suffix"}};
        }
    }

    if (my $pointer = $overridden{'dh_auto_test'}) {
        my @rules = grep {
                 !m{^\t\s*[\:\[]}
              && !m{^\s*$}
              && !m{\bdh_auto_test\b}
              && !
m{^\t\s*[-@]?(?:(?:/usr)?/bin/)?(?:cp|chmod|echo|ln|mv|mkdir|rm|test|true)}
        } @{$rules_per_target{'override_dh_auto_test'}};
        $self->hint('override_dh_auto_test-does-not-check-DEB_BUILD_OPTIONS',
            "(line $pointer)")
          if @rules and none { m/(DEB_BUILD_OPTIONS|nocheck)/ } @conditionals;
    }

    $self->hint('debian-rules-contains-unnecessary-get-orig-source-target')
      if any { m/^\s+uscan\b/ } @{$rules_per_target{'get-orig-source'}};

    my @clean_in_indep
      = grep { $build_indep->satisfies($_) } uniq @needed_clean;
    $self->hint('missing-build-depends-for-clean-target-in-debian-rules',
        "(does not satisfy $_)")
      for @clean_in_indep;

    # another check complains when debhelper is missing from d/rules
    my $combined_lc = List::Compare->new(\@needed, ['debhelper']);

    my @still_missing
      = grep { !$build_all_norestriction->satisfies($_) }
      $combined_lc->get_Lonly;

    $self->hint('rules-require-build-prerequisite', "(does not satisfy $_)")
      for @still_missing;

    $self->hint('debian-rules-should-not-set-CFLAGS-from-noopt')
      if $contents
      =~ m{^ ifn?eq \s+ [(] , \$ [(] findstring \s+ noopt , \$ [(] DEB_BUILD_OPTIONS [)] [)] [)] \n+
                        \t+ CFLAGS \s+ \+ = \s+ -O[02] \n+
                        else \n+
                        \t+ CFLAGS \s+ \+ = \s+ -O[02] \n+
                        endif $}xsm;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

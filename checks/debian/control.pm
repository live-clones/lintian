# debian/control -- lintian check script -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Chris Lamb <lamby@debian.org>
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

package Lintian::debian::control;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::SomeUtils qw(any);
use List::Util qw(first none);
use Path::Tiny;

use Lintian::Deb822::Parser qw(parse_dpkg_control_string);
use Lintian::Relation ();

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# The list of libc packages, used for checking for a hard-coded dependency
# rather than using ${shlibs:Depends}.
my @LIBCS = qw(libc6 libc6.1 libc0.1 libc0.3);
my $LIBCS = Lintian::Relation->new(join(' | ', @LIBCS));

sub source {
    my ($self) = @_;

    my $processable = $self->processable;
    my $group = $self->group;

    my $debian_dir = $processable->patched->resolve_path('debian/');
    return
      unless $debian_dir;

    my $dcontrol = $debian_dir->child('control');
    return
      unless $dcontrol;

    $self->hint('debian-control-file-is-a-symlink')
      if $dcontrol->is_symlink;

    return
      unless $dcontrol->is_open_ok;

    # another check complains about invalid encoding
    return
      unless $dcontrol->is_valid_utf8;

    my $src_fields = $self->profile->load_data('common/source-fields');

    my $contents = $dcontrol->decoded_utf8;
    my @lines = split(/\n/, $contents);

    # Nag about dh_make Vcs comment only once
    my $seen_vcs_comment = 0;

    my $line;
    my $position = 1;
    while (defined($line = shift @lines)) {

        $line =~ s/\s*$//;

        if (
            $line =~ m{\A \# \s* Vcs-(?:Git|Browser): \s*
                  (?:git|http)://git\.debian\.org/
                  (?:\?p=)?collab-maint/<pkg>\.git}smx
        ) {
            # Emit it only once per package
            $self->hint('control-file-contains-dh_make-vcs-comment')
              unless $seen_vcs_comment++;
            next;
        }

        next
          if $line =~ /^\#/;

        # line with field:
        if ($line =~ /^(\S+):/) {

            my $field = $1;

            if ($field =~ /^XS-Vcs-/) {
                my $base = $field;
                $base =~ s/^XS-//;
                $self->hint('xs-vcs-field-in-debian-control', $field)
                  if $src_fields->known($base);
            }

            if ($field eq 'XS-Testsuite') {
                $self->hint('xs-testsuite-field-in-debian-control', $field);
            }

            if ($field eq 'XC-Package-Type') {
                $self->hint('xc-package-type-in-debian-control',
                    "line $position");
            }

            unless ($line =~ /^\S+: \S/ || $line =~ /^\S+:$/) {
                $self->hint('debian-control-has-unusual-field-spacing',
                    "line $position");
            }

            # something like "Maintainer: Maintainer: bad field"
            if ($line =~ /^\Q$field\E: \s* \Q$field\E \s* :/xsmi) {
                $self->hint('debian-control-repeats-field-name-in-value',
                    "line $position");
            }

            if (    $field =~ /^Rules?-Requires?-Roots?$/i
                and $field ne 'Rules-Requires-Root') {
                $self->hint('spelling-error-in-rules-requires-root',
                    $field,"(line $position)");
            }
        }
    }continue {
        ++$position;
    }

    eval {
        # check we can parse it, but ignore the result - we will fetch
        # the fields we need from $processable.
        parse_dpkg_control_string($contents);
    };
    if ($@) {
        chomp $@;
        $@ =~ s/^internal error: //;
        $@ =~ s/^syntax error in //;
        die "syntax error in debian/control: $@";
    }

    for my $field ($processable->debian_control->source_fields->names) {
        $self->hint(
            'debian-control-has-empty-field',
            "field \"$field\" in source paragraph",
          )
          unless
          length $processable->debian_control->source_fields->value($field);
    }

    my @package_names = $processable->debian_control->installables;

    foreach my $bin (@package_names) {
        my $bfields = $processable->debian_control->installable_fields($bin);
        $self->hint('build-info-in-binary-control-file-section',"Package $bin")
          if (
            first { $bfields->value("Build-$_") }
            qw(Depends Depends-Indep Conflicts Conflicts-Indep)
          );
        foreach my $field ($bfields->names) {
            $self->hint(
                'binary-control-field-duplicates-source',
                "field \"$field\" in package $bin"
              )
              if ($processable->debian_control->source_fields->declares($field)
                && $bfields->value($field) eq
                $processable->debian_control->source_fields->value($field));
            $self->hint(
                'debian-control-has-empty-field',
                "field \"$field\" in package $bin",
            ) if $bfields->value($field) eq '';
        }
        if ($bin =~ /[-]dbgsym$/) {
            $self->hint('debian-control-has-dbgsym-package', $bin);
        }
        if ($bin =~ /[-]dbg$/) {
            $self->hint('debian-control-has-obsolete-dbg-package', $bin)
              unless $self->dbg_pkg_is_known($bin);
        }
    }

    # Check that fields which should be comma-separated or
    # pipe-separated have separators.  Places where this tends to
    # cause problems are with wrapped lines such as:
    #
    #     Depends: foo, bar
    #      baz
    #
    # or with substvars.  If two substvars aren't separated by a
    # comma, but at least one of them expands to an empty string,
    # there will be a lurking bug.  The result will be syntactically
    # correct, but as soon as both expand into something non-empty,
    # there will be a syntax error.
    #
    # The architecture list can contain things that look like packages
    # separated by spaces, so we have to remove any architecture
    # restrictions first.  This unfortunately distorts our report a
    # little, but hopefully not too much.
    #
    # Also check for < and > relations.  dpkg-gencontrol warns about
    # them and then transforms them in the output to <= and >=, but
    # it's easy to miss the error message.  Similarly, check for
    # duplicates, which dpkg-source eliminates.

    for my $field (
        qw(Build-Depends Build-Depends-Indep
        Build-conflicts Build-Conflicts-Indep)
    ) {
        next
          unless $processable->debian_control->source_fields->declares($field);
        my $raw = $processable->debian_control->source_fields->value($field);
        my $rel;
        $rel = Lintian::Relation->new($raw);
        $self->check_relation('source', $field, $raw, $rel);
    }

    for my $bin (@package_names) {
        for my $field (
            qw(Pre-Depends Depends Recommends Suggests Breaks
            Conflicts Provides Replaces Enhances)
        ) {
            next
              unless $processable->debian_control->installable_fields($bin)
              ->declares($field);

            my $raw
              = $processable->debian_control->installable_fields($bin)
              ->value($field);
            my $rel;
            $rel = $processable->binary_relation($bin, $field);
            $self->check_relation($bin, $field, $raw, $rel);
        }
    }

    # Make sure that a stronger dependency field doesn't imply any of
    # the elements of a weaker dependency field.  dpkg-gencontrol will
    # fix this up for us, but we want to check the source package
    # since dpkg-gencontrol may silently "fix" something that's a more
    # subtle bug.
    #
    # Also check if a package declares a simple dependency on itself,
    # since similarly dpkg-gencontrol will clean this up for us but it
    # may be a sign of another problem, and check that the package
    # doesn't hard-code a dependency on libc.  We have to do the
    # latter check here rather than in checks/fields to distinguish
    # from dependencies created by ${shlibs:Depends}.
    my @dep_fields = qw(Pre-Depends Depends Recommends Suggests);
    foreach my $bin (@package_names) {
        for my $strong (0 .. $#dep_fields) {
            next
              unless $processable->debian_control->installable_fields($bin)
              ->declares($dep_fields[$strong]);
            my $relation
              = $processable->binary_relation($bin, $dep_fields[$strong]);
            $self->hint('package-depends-on-itself', $bin,$dep_fields[$strong])
              if $relation->implies($bin);
            $self->hint('package-depends-on-hardcoded-libc',
                $bin, $dep_fields[$strong])
              if $relation->implies($LIBCS)
              and $self->processable->name !~ /^e?glibc$/;
            for my $weak (($strong + 1) .. $#dep_fields) {
                next
                  unless $processable->debian_control->installable_fields($bin)
                  ->declares($dep_fields[$weak]);
                for my $dependency (split /\s*,\s*/,
                    $processable->debian_control->installable_fields($bin)
                    ->value($dep_fields[$weak])) {
                    next unless $dependency;
                    $self->hint('stronger-dependency-implies-weaker',
                        $bin,"$dep_fields[$strong] -> $dep_fields[$weak]",
                        $dependency)
                      if $relation->implies($dependency);
                }
            }
        }
    }

    # Check that every package is in the same archive area, except
    # that sources in main can deliver both main and contrib packages.
    # The source package may or may not have a section specified; if
    # it doesn't, derive the expected archive area from the first
    # binary package by leaving $area undefined until parsing the
    # first binary section.  Missing sections will be caught by other
    # checks.
    #
    # Check any package that looks like a library -dev package for a
    # dependency on a shared library package built from the same
    # source.  If found, such a dependency should have a tight version
    # dependency on that package.
    #
    # Also accumulate short and long descriptions for each package so
    # that we can check for duplication, but skip udeb packages.
    # Ideally, we should check the udeb package descriptions
    # separately for duplication, but udeb packages should be able to
    # duplicate the descriptions of non-udeb packages and the package
    # description for udebs is much less important or significant to
    # the user.

    my $area = $processable->debian_control->source_fields->value('Section');

    if ($area =~ m{^([^/]+)/}) {
        $area = $1;
    } else {
        $area = 'main';
    }

    my @descriptions;
    my ($seen_main, $seen_contrib);
    foreach my $bin (@package_names) {
        my $depends
          = $processable->debian_control->installable_fields($bin)
          ->value('Depends');

        # Accumulate the description.
        my $desc = $processable->debian_control->installable_fields($bin)
          ->untrimmed_value('Description');
        my $bin_area;
        if (length $desc
            and $processable->debian_control->installable_package_type($bin)ne
            'udeb') {
            push @descriptions, [$bin, split(/\n/, $desc, 2)];
        }

        # If this looks like a -dev package, check its dependencies.
        if ($bin =~ /-dev$/ and $depends) {
            $self->check_dev_depends($bin, $depends, @package_names);
        }

        if ($depends =~ m/\$\{misc:Pre-Depends\}/) {
            $self->hint('depends-on-misc-pre-depends', $bin);
        }

        # Check mismatches in archive area.
        $bin_area
          = $processable->debian_control->installable_fields($bin)
          ->value('Section');
        $seen_main = 1 if not length($bin_area) and $area eq 'main';
        next
          unless length $area && length $bin_area;

        if ($bin_area =~ m{^([^/]+)/}) {
            $bin_area = $1;
        } else {
            $bin_area = 'main';
        }
        $seen_main = 1 if $bin_area eq 'main';
        $seen_contrib = 1 if $bin_area eq 'contrib';
        next
          if $area eq $bin_area
          or ($area eq 'main' and $bin_area eq 'contrib');

        $self->hint('section-area-mismatch', 'Package', $bin);
    }

    $self->hint('section-area-mismatch')
      if $seen_contrib
      and not $seen_main
      and $area eq 'main';

    my %short_descriptions;
    my %long_descriptions;

    for my $paragraph (@descriptions) {

        my $package = @{$paragraph}[0];

        my $short = @{$paragraph}[1];
        if (length $short) {
            $short_descriptions{$short} //= [];
            push(@{$short_descriptions{$short}}, $package);
        }

        my $long = @{$paragraph}[2];
        if (length $long) {
            $long_descriptions{$long} //= [];
            push(@{$long_descriptions{$long}}, $package);
        }
    }

    # check for duplicate short description
    for my $short (keys %short_descriptions) {
        # Assume that substvars are correctly handled
        next if $short =~ m/\$\{.+\}/;
        $self->hint(
            'duplicate-short-description',
            sort @{$short_descriptions{$short}}
        )if scalar @{$short_descriptions{$short}} > 1;
    }

    # check for duplicate long description
    for my $long (keys %long_descriptions) {
        # Assume that substvars are correctly handled
        next if $long =~ m/\$\{.+\}/;
        $self->hint('duplicate-long-description',
            sort @{$long_descriptions{$long}})
          if scalar @{$long_descriptions{$long}} > 1;
    }

    my $KNOWN_BUILD_PROFILES
      = $self->profile->load_data('fields/build-profiles');

    # check the syntax of the Build-Profiles field
    for my $bin (@package_names) {
        my $raw = $processable->debian_control->installable_fields($bin)
          ->value('Build-Profiles');
        next unless $raw;
        if (
            $raw!~ m{^\s*              # skip leading whitespace
                     <                 # first list start
                       !?[^\s<>]+      # (possibly negated) term
                       (?:             # any additional terms
                         \s+           # start with a space
                         !?[^\s<>]+    # (possibly negated) term
                       )*              # zero or more additional terms
                     >                 # first list end
                     (?:               # any additional restriction lists
                       \s+             # start with a space
                       <               # additional list start
                         !?[^\s<>]+    # (possibly negated) term
                         (?:           # any additional terms
                           \s+         # start with a space
                           !?[^\s<>]+  # (possibly negated) term
                         )*            # zero or more additional terms
                       >               # additional list end
                     )*                # zero or more additional lists
                     \s*$              # trailing spaces at the end
              }x
        ) {
            $self->hint('invalid-restriction-formula-in-build-profiles-field',
                $raw,$bin);
        } else {
            # parse the field and check the profile names
            $raw =~ s/^\s*<(.*)>\s*$/$1/;
            for my $restrlist (split />\s+</, $raw) {
                for my $profile (split /\s+/, $restrlist) {
                    $profile =~ s/^!//;
                    $self->hint('invalid-profile-name-in-build-profiles-field',
                        $profile, $bin)
                      unless $KNOWN_BUILD_PROFILES->known($profile)
                      or $profile =~ /^pkg\.[a-z0-9][a-z0-9+.-]+\../;
                }
            }
        }
    }

    # Check Rules-Requires-Root
    if (
        $processable->debian_control->source_fields->declares(
            'Rules-Requires-Root')
    ) {
        my $r3
          = $processable->debian_control->source_fields->value(
            'Rules-Requires-Root');
        if ($r3 eq 'no') {
            $self->hint('rules-does-not-require-root');
        } else {
            $self->hint('rules-requires-root-explicitly');
        }
    } else {
        $self->hint('silent-on-rules-requiring-root');
    }

    if ((
            $processable->debian_control->source_fields->value(
                'Rules-Requires-Root')
            || 'no'
        ) eq 'no'
    ) {
      BINARY:
        foreach my $proc ($group->get_binary_processables) {
            my $pkg = $proc->name;
            foreach my $file ($proc->installed->sorted_list) {
                my $owner = $file->owner . ':' . $file->group;
                next if $owner eq 'root:root';
                $self->hint('rules-silently-require-root',
                    $pkg, $file,"($owner)");
                last BINARY;
            }
        }
    }

    # Make sure that the Architecture field in source packages is not multiline
    for my $bin (@package_names) {
        # The Architecture field is mandatory and dpkg-buildpackage
        # will already bail out if it's missing, so we don't need to
        # check that.
        my $raw = $processable->debian_control->installable_fields($bin)
          ->value('Architecture');
        if ($raw =~ /\n./) {
            $self->hint('multiline-architecture-field',$bin);
        }
    }

    # Check for GObject Introspection packages that are missing ${gir:Depends}
    foreach my $bin (@package_names) {
        next unless $bin =~ m/gir[\d\.]+-.*-[\d\.]+$/;
        my $relation = $processable->binary_relation($bin, 'all');
        $self->hint(
            'gobject-introspection-package-missing-depends-on-gir-depends',
            $bin)
          unless $relation->implies('${gir:Depends}');
    }

    if ($processable->relation('Build-Depends')
        ->implies('golang-go | golang-any')) {
        # Verify that golang binary packages set Built-Using (except for
        # arch:all library packages).
        foreach my $bin (@package_names) {
            my $bu = $processable->debian_control->installable_fields($bin)
              ->value('Built-Using');
            my $arch = $processable->debian_control->installable_fields($bin)
              ->value('Architecture');
            if ($arch eq 'all') {
                $self->hint('built-using-field-on-arch-all-package', $bin)
                  if length $bu;
            } else {
                if (!length($bu) || $bu !~ /\$\{misc:Built-Using\}/) {
                    $self->hint('missing-built-using-field-for-golang-package',
                        $bin);
                }
            }
        }

        $self->hint('missing-xs-go-import-path-for-golang-package')
          unless (
            $processable->debian_control->source_fields->value(
                'XS-Go-Import-Path'));
    }

    my $changes = $group->changes;
    $self->hint('source-only-upload-to-non-free-without-autobuild')
      if defined($changes)
      and $changes->fields->value('Architecture') eq 'source'
      and $processable->is_non_free
      and ($processable->debian_control->source_fields->value('XS-Autobuild')
        || 'no')eq 'no';

    return;
}

# check debug package
sub dbg_pkg_is_known {
    my ($self, $pkg) = @_;

    my $KNOWN_DBG_PACKAGE = $self->profile->load_data(
        'common/dbg-pkg',
        qr/\s*\~\~\s*/,
        sub {
            return qr/$_[0]/xms;
        });

    foreach my $dbg_regexp ($KNOWN_DBG_PACKAGE->all) {
        my $regex = $KNOWN_DBG_PACKAGE->value($dbg_regexp);
        if($pkg =~ m/$regex/xms) {
            return 1;
        }
    }
    return 0;
}

# Check the dependencies of a -dev package.  Any dependency on one of the
# packages in @packages that looks like the underlying library needs to
# have a version restriction that's at least as strict as the same upstream
# version.
sub check_dev_depends {
    my ($self, $package, $depends, @packages) = @_;

    my $processable = $self->processable;

    # trim both ends
    $depends =~ s/^\s+|\s+$//g;

    for my $target (@packages) {
        next
          unless ($target =~ /^lib[\w.+-]+\d/
            and $target !~ /-(?:dev|docs?|common)$/);
        my @depends = grep { /(?:^|[\s|])\Q$target\E(?:[\s|\(]|\z)/ }
          split(/\s*,\s*/, $depends);

        # If there are any alternatives here, something special is
        # going on.  Assume that the maintainer knows what they're
        # doing.  Otherwise, separate out just the versions.
        next if any { /\|/ } @depends;
        my @versions = sort map {
            if (/^[\w.+-]+(?:\s*\(([^\)]+)\))/) {
                $1;
            } else {
                '';
            }
        } @depends;

        # If there's only one mention of this package, the dependency
        # should be tight.  Otherwise, there should be both >>/>= and
        # <</<= dependencies that mention the source, binary, or
        # upstream version.  If there are more than three mentions of
        # the package, again something is weird going on, so we assume
        # they know what they're doing.
        if (@depends == 1) {
            unless ($versions[0]
                =~ /^\s*=\s*\$\{(?:binary:Version|Source-Version)\}/) {
                # Allow "pkg (= ${source:Version})" if (but only if)
                # the target is an arch:all package.  This happens
                # with a lot of mono-packages.
                #
                # Note, we do not check if the -dev package is
                # arch:all as well.  The version-substvars check
                # handles that for us.
                next
                  if$processable->debian_control->installable_fields($target)
                  ->value('Architecture') eq 'all'
                  && $versions[0] =~ /^\s*=\s*\$\{source:Version\}/;
                $self->hint('weak-library-dev-dependency',
                    "$package on $depends[0]");
            }
        } elsif (@depends == 2) {
            unless (
                $versions[0] =~ m/^\s*<[=<]\s* \$\{
                        (?: (?:binary|source):(?:Upstream-)?Version
                            |Source-Version)\}/xsm
                && $versions[1] =~ m/^\s*>[=>]\s* \$\{
                        (?: (?:binary|source):(?:Upstream-)?Version
                        |Source-Version)\}/xsm
            ) {
                $self->hint('weak-library-dev-dependency',
                    "$package on $depends[0], $depends[1]");
            }
        }
    }
    return;
}

# Checks for duplicates in a relation, for missing separators and
# obsolete relation forms.
sub check_relation {
    my ($self, $pkg, $field, $rawvalue, $relation) = @_;

    for my $dup ($relation->duplicates) {
        $self->hint('duplicate-in-relation-field', 'in', $pkg,
            "$field:", join(', ', @$dup));
    }

    $rawvalue =~ s/\n(\s)/$1/g;
    $rawvalue =~ s/\[[^\]]*\]//g;
    if (
        $rawvalue =~ /(?:^|\s)
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )
                   \s+
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )/x
    ) {
        my ($prev, $next) = ($1, $2);
        for ($prev, $next) {
            # trim right
            s/\s+$//;
        }
        $self->hint('missing-separator-between-items',
            'in', $pkg,"$field field between '$prev' and '$next'");
    }
    while ($rawvalue =~ /([^\s\(]+\s*\([<>]\s*[^<>=]+\))/g) {
        $self->hint('obsolete-relation-form-in-source','in', $pkg,
            "$field: $1");
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

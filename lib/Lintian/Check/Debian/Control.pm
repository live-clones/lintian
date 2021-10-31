# debian/control -- lintian check script -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Check::Debian::Control;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none first_value);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::Parser qw(parse_dpkg_control_string);
use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $COLON => q{:};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

const my $ARROW => q{->};

# The list of libc packages, used for checking for a hard-coded dependency
# rather than using ${shlibs:Depends}.
my @LIBCS = qw(libc6 libc6.1 libc0.1 libc0.3);
my $LIBCS = Lintian::Relation->new->load(join(' | ', @LIBCS));

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless $debian_dir;

    my $file = $debian_dir->child('control');
    return
      unless $file;

    $self->hint('debian-control-file-is-a-symlink')
      if $file->is_symlink;

    return
      unless $file->is_open_ok;

    # another check complains about invalid encoding
    return
      unless $file->is_valid_utf8;

    my $KNOWN_SOURCE_FIELDS= $self->profile->load_data('common/source-fields');

    my $contents = $file->decoded_utf8;
    my @lines = split(/\n/, $contents);

    # Nag about dh_make Vcs comment only once
    my $seen_vcs_comment = 0;

    my $line;
    my $position = 1;
    while (defined($line = shift @lines)) {

        $line =~ s{\s*$}{};

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
          if $line =~ m{^#};

        # line with field:
        if ($line =~ m{^ (\S+) : }x) {

            my $field = $1;

            my $pointer = "[line $position]";

            if ($field =~ /^XS-Vcs-/) {

                my $base = $field;
                $base =~ s/^XS-//;

                $self->hint('xs-vcs-field-in-debian-control', $field, $pointer)
                  if $KNOWN_SOURCE_FIELDS->recognizes($base);
            }

            $self->hint('xs-testsuite-field-in-debian-control',
                $field, $pointer)
              if $field eq 'XS-Testsuite';

            $self->hint('xc-package-type-in-debian-control', $pointer)
              if $field eq 'XC-Package-Type';

            $self->hint('debian-control-has-unusual-field-spacing',$pointer)
              unless $line =~ m{^ \S+ : [ ] \S }x
              || $line =~ m{^ \S+ : $}x;

            # something like "Maintainer: Maintainer: bad field"
            $self->hint('debian-control-repeats-field-name-in-value',$pointer)
              if $line =~ m{^\Q$field\E: \s* \Q$field\E \s* :}xsmi;

            $self->hint('spelling-error-in-rules-requires-root',
                $field, $pointer)
              if $field ne 'Rules-Requires-Root'
              && $field =~ m{^ Rules? - Requires? - Roots? $}xi;
        }

    } continue {
        ++$position;
    }

    eval {
        # check we can parse it, but ignore the result - we will fetch
        # the fields we need from $self->processable.
        parse_dpkg_control_string($contents);
    };
    if ($@) {

        chomp $@;

        $@ =~ s/^internal error: //;
        $@ =~ s/^syntax error in //;

        die encode_utf8("syntax error in debian/control: $@");
    }

    my @empty_fields
      = grep { !length $source_fields->value($_) }$source_fields->names;

    $self->hint('debian-control-has-empty-field',$_, '(in source paragraph)')
      for @empty_fields;

    my @package_names = $control->installables;

    for my $installable (@package_names) {
        my $installable_fields = $control->installable_fields($installable);

        my $pointer = "(in section for $installable)";

        my @build_fields = grep { $installable_fields->declares($_) }
          qw{Build-Depends Build-Depends-Indep Build-Conflicts Build-Conflicts-Indep};

        $self->hint('build-info-in-binary-control-file-section',
            sort(@build_fields), $pointer)
          if @build_fields;

        for my $field ($installable_fields->names) {

            $self->hint('binary-control-field-duplicates-source',
                $field, $pointer)
              if $source_fields->declares($field)
              && $installable_fields->value($field) eq
              $source_fields->value($field);

            $self->hint('debian-control-has-empty-field',$field, $pointer,)
              unless length $installable_fields->value($field);
        }

        $self->hint('debian-control-has-dbgsym-package', $installable)
          if $installable =~ /[-]dbgsym$/;

        my $KNOWN_LEGACY_DBG_PATTERNS
          = $self->profile->load_data('common/dbg-pkg');

        $self->hint('debian-control-has-obsolete-dbg-package', $installable)
          if $installable =~ /[-]dbg$/
          && none { $installable =~ m/$_/xms } $KNOWN_LEGACY_DBG_PATTERNS->all;
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
        Build-Conflicts Build-Conflicts-Indep)
    ) {
        next
          unless $source_fields->declares($field);

        my $raw = $source_fields->value($field);

        my $relation = Lintian::Relation->new->load($raw);
        $self->check_relation('source', $field, $raw, $relation);
    }

    for my $installable (@package_names) {

        for my $field (
            qw(Pre-Depends Depends Recommends Suggests Breaks
            Conflicts Provides Replaces Enhances)
        ) {
            next
              unless $control->installable_fields($installable)
              ->declares($field);

            my $raw= $control->installable_fields($installable)->value($field);

            my $relation
              = $self->processable->binary_relation($installable, $field);
            $self->check_relation($installable, $field, $raw, $relation);
        }
    }

    # Make sure that a stronger dependency field doesn't satisfy any of
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

    # ordered from stronger to weaker
    my @ordered_fields = qw(Pre-Depends Depends Recommends Suggests);

    for my $installable (@package_names) {

        my @remaining_fields = @ordered_fields;

        for my $stronger (@ordered_fields) {

            shift @remaining_fields;

            next
              unless $control->installable_fields($installable)
              ->declares($stronger);

            my $relation
              = $self->processable->binary_relation($installable,$stronger);

            $self->hint('package-depends-on-itself', $installable,$stronger)
              if $relation->satisfies($installable);

            $self->hint('package-depends-on-hardcoded-libc',
                $installable, $stronger)
              if $relation->satisfies($LIBCS)
              && $self->processable->name !~ /^e?glibc$/;

            for my $weaker (@remaining_fields) {

                my @prerequisites = $control->installable_fields($installable)
                  ->trimmed_list($weaker, qr{\s*,\s*});

                for my $prerequisite (@prerequisites) {

                    $self->hint('stronger-dependency-implies-weaker',
                        $installable, $stronger, $ARROW,$weaker,$prerequisite)
                      if $relation->satisfies($prerequisite);
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

    my $area = $source_fields->value('Section');

    if ($area =~ m{^([^/]+)/}) {
        $area = $1;
    } else {
        $area = 'main';
    }

    my $seen_main;
    my $seen_contrib;

    for my $installable (@package_names) {

        my $depends
          = $control->installable_fields($installable)->value('Depends');

        # If this looks like a -dev package, check its dependencies.
        $self->check_dev_depends($installable, $depends, @package_names)
          if $installable =~ /-dev$/ && defined $depends;

        $self->hint('depends-on-misc-pre-depends', $installable)
          if $depends =~ m/\$\{misc:Pre-Depends\}/;

        # Check mismatches in archive area.
        my $installable_area
          = $control->installable_fields($installable)->value('Section');
        $seen_main = 1
          if $area eq 'main'
          && !length($installable_area);

        next
          unless length $area
          && length $installable_area;

        if ($installable_area =~ m{^([^/]+)/}) {
            $installable_area = $1;
        } else {
            $installable_area = 'main';
        }

        $seen_main = 1
          if $installable_area eq 'main';

        $seen_contrib = 1
          if $installable_area eq 'contrib';

        next
          if $area eq $installable_area
          || ($area eq 'main' && $installable_area eq 'contrib');

        $self->hint('section-area-mismatch', 'Package', $installable);
    }

    $self->hint('section-area-mismatch')
      if $seen_contrib
      && !$seen_main
      && $area eq 'main';

    my %installables_by_synopsis;
    my %installables_by_exended;

    for my $installable (@package_names) {

        my $description
          = $control->installable_fields($installable)
          ->untrimmed_value('Description');

        next
          unless length $description;

        next
          if $control->installable_package_type($installable) eq 'udeb';

        my ($synopsis, $extended) = split(/\n/, $description, 2);

        $synopsis //= $EMPTY;
        $extended //= $EMPTY;

        # trim both ends
        $synopsis =~ s/^\s+|\s+$//g;
        $extended =~ s/^\s+|\s+$//g;

        if (length $synopsis) {
            $installables_by_synopsis{$synopsis} //= [];
            push(@{$installables_by_synopsis{$synopsis}}, $installable);
        }

        if (length $extended) {
            $installables_by_exended{$extended} //= [];
            push(@{$installables_by_exended{$extended}}, $installable);
        }
    }

    # check for duplicate short description
    for my $synopsis (keys %installables_by_synopsis) {

        # Assume that substvars are correctly handled
        next
          if $synopsis =~ m/\$\{.+\}/;

        $self->hint('duplicate-short-description',
            sort @{$installables_by_synopsis{$synopsis}})
          if scalar @{$installables_by_synopsis{$synopsis}} > 1;
    }

    # check for duplicate long description
    for my $extended (keys %installables_by_exended) {

        # Assume that substvars are correctly handled
        next
          if $extended =~ m/\$\{.+\}/;

        $self->hint('duplicate-long-description',
            sort @{$installables_by_exended{$extended}})
          if scalar @{$installables_by_exended{$extended}} > 1;
    }

    my $KNOWN_BUILD_PROFILES
      = $self->profile->load_data('fields/build-profiles');

    # check the syntax of the Build-Profiles field
    for my $installable (@package_names) {

        my $raw = $control->installable_fields($installable)
          ->value('Build-Profiles');
        next
          unless $raw;

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
                $raw,$installable);

        } else {
            # parse the field and check the profile names
            $raw =~ s/^\s*<(.*)>\s*$/$1/;
            for my $restrlist (split />\s+</, $raw) {
                for my $profile (split /\s+/, $restrlist) {

                    $profile =~ s/^!//;

                    $self->hint('invalid-profile-name-in-build-profiles-field',
                        $profile, $installable)
                      unless $KNOWN_BUILD_PROFILES->recognizes($profile)
                      || $profile =~ /^pkg\.[a-z0-9][a-z0-9+.-]+\../;
                }
            }
        }
    }

    $self->hint('rules-does-not-require-root')
      if $source_fields->value('Rules-Requires-Root') eq 'no';

    $self->hint('rules-requires-root-explicitly')
      if $source_fields->declares('Rules-Requires-Root')
      && $source_fields->value('Rules-Requires-Root') ne 'no';

    $self->hint('silent-on-rules-requiring-root')
      unless $source_fields->declares('Rules-Requires-Root');

    if (  !$source_fields->declares('Rules-Requires-Root')
        || $source_fields->value('Rules-Requires-Root') eq 'no') {

        for my $other ($self->group->get_binary_processables) {

            my $user_owned_item
              = first_value { $_->owner ne 'root' || $_->group ne 'root' }
            @{$other->installed->sorted_list};

            $self->hint(
                'rules-silently-require-root',
                $other->name,
                $user_owned_item->name,
                $LEFT_PARENTHESIS
                  . $user_owned_item->owner
                  . $COLON
                  . $user_owned_item->group
                  . $RIGHT_PARENTHESIS
            )if defined $user_owned_item;
        }
    }

    for my $installable (@package_names) {

        $self->hint('multiline-architecture-field',$installable)
          if $control->installable_fields($installable)->value('Architecture')
          =~ /\n./;
    }

    for my $installable (@package_names) {

        next
          unless $installable =~ m/gir[\d\.]+-.*-[\d\.]+$/;

        my $relation= $self->processable->binary_relation($installable, 'all');

        $self->hint(
            'gobject-introspection-package-missing-depends-on-gir-depends',
            $installable)
          unless $relation->satisfies('${gir:Depends}');
    }

    if ($self->processable->relation('Build-Depends')
        ->satisfies('golang-go | golang-any')) {

        # Verify that golang binary packages set Built-Using (except for
        # arch:all library packages).
        for my $installable (@package_names) {

            my $built_using = $control->installable_fields($installable)
              ->value('Built-Using');

            my $arch
              = $control->installable_fields($installable)
              ->value('Architecture');

            if ($arch eq 'all') {

                $self->hint('built-using-field-on-arch-all-package',
                    $installable)
                  if length $built_using;

            } else {
                $self->hint('missing-built-using-field-for-golang-package',
                    $installable)
                  unless length($built_using)
                  && $built_using =~ /\$\{misc:Built-Using\}/;
            }
        }

        $self->hint('missing-xs-go-import-path-for-golang-package')
          unless ($source_fields->value('XS-Go-Import-Path'));
    }

    if (defined $self->group->changes) {

        my $group_fields = $self->group->changes->fields;

        $self->hint('source-only-upload-to-non-free-without-autobuild')
          if $group_fields->value('Architecture') eq 'source'
          && $self->processable->is_non_free
          && (!$source_fields->declares('XS-Autobuild')
            || $source_fields->value('XS-Autobuild') eq 'no');
    }

    return;
}

# Check the dependencies of a -dev package.  Any dependency on one of the
# packages in @packages that looks like the underlying library needs to
# have a version restriction that's at least as strict as the same upstream
# version.
sub check_dev_depends {
    my ($self, $package, $depends, @packages) = @_;

    my $control = $self->processable->debian_control;

    # trim both ends
    $depends =~ s/^\s+|\s+$//g;

    for my $target (@packages) {

        next
          if $target =~ /-(?:dev|docs?|common)$/;

        next
          unless $target =~ /^lib[\w.+-]+\d/;

        my @depends = grep { /(?:^|[\s|])\Q$target\E(?:[\s|\(]|\z)/ }
          split(/\s*,\s*/, $depends);

        # If there are any alternatives here, something special is
        # going on.  Assume that the maintainer knows what they're
        # doing.  Otherwise, separate out just the versions.
        next if any { /\|/ } @depends;

        my @unsorted;
        for my $item (@depends) {
            if ($item =~ /^[\w.+-]+(?:\s*\(([^\)]+)\))/) {
                push(@unsorted, $1);
            } else {
                push(@unsorted, $EMPTY);
            }
        }

        my @versions = sort @unsorted;

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
                  if $control->installable_fields($target)
                  ->value('Architecture') eq 'all'
                  && $versions[0] =~ /^\s*=\s*\$\{source:Version\}/;
                $self->hint('weak-library-dev-dependency',
                    "$package on $depends[0]");
            }
        } elsif (@depends == 2) {
            unless (
                $versions[0] =~ m{^\s*<[=<]\s* \$\{
                        (?: (?:binary|source):(?:Upstream-)?Version
                            |Source-Version)\}}xsm
                && $versions[1] =~ m{^\s*>[=>]\s* \$\{
                        (?: (?:binary|source):(?:Upstream-)?Version
                        |Source-Version)\}}xsm
            ) {
                $self->hint('weak-library-dev-dependency',
                    "$package on $depends[0], $depends[1]");
            }
        }
    }

    return;
}

# Checks for redundancies in a relation, for missing separators and
# obsolete relation forms.
sub check_relation {
    my ($self, $package, $field, $string, $relation) = @_;

    my $pointer = "($field for $package)";

    for my $redundant_set ($relation->redundancies) {

        $self->hint('redundant-control-relation',
            join(', ', sort @{$redundant_set}), $pointer);
    }

    $string =~ s/\n(\s)/$1/g;
    $string =~ s/\[[^\]]*\]//g;

    if (
        $string =~ m{(?:^|\s)
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )
                   \s+
                   (
                (?:\w[^\s,|\$\(]+|\$\{\S+:Depends\})\s*
                (?:\([^\)]*\)\s*)?
                   )}x
    ) {
        my ($prev, $next) = ($1, $2);

        # trim right
        $prev =~ s/\s+$//;
        $next =~ s/\s+$//;

        $self->hint('missing-separator-between-items',
            "between '$prev' and '$next'", $pointer);
    }

    while ($string =~ /([^\s\(]+\s*\([<>]\s*[^<>=]+\))/g) {

        $self->hint('obsolete-relation-form-in-source', $1, $pointer);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

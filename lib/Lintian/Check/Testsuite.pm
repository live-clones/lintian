# testsuite -- lintian check script -*- perl -*-

# Copyright (C) 2013 Nicolas Boulenguez <nicolas@debian.org>
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner

# This file is part of lintian.

# Lintian is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Lintian is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Lintian.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Check::Testsuite;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any none uniq);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822;
use Lintian::Deb822::Constants qw(DCTRL_COMMENTS_AT_EOL);
use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $DOT => q{.};
const my $DOUBLE_QUOTE => q{"};

const my @KNOWN_FIELDS => qw(
  Tests
  Restrictions
  Features
  Depends
  Tests-Directory
  Test-Command
  Architecture
  Classes
);

my %KNOWN_FEATURES = map { $_ => 1 } qw();

our $PYTHON3_ALL_DEPEND
  = 'python3-all:any | python3-all-dev:any | python3-all-dbg:any';

my %KNOWN_SPECIAL_DEPENDS = map { $_ => 1 } qw(
  @
  @builddeps@
  @recommends@
);

sub source {
    my ($self) = @_;

    my $KNOWN_TESTSUITES= $self->data->load('testsuite/known-testsuites');

    my $debian_control = $self->processable->debian_control;

    my $testsuite = $debian_control->source_fields->value('Testsuite');
    my @testsuites = split(/\s*,\s*/, $testsuite);

    my $lc = List::Compare->new(\@testsuites, [$KNOWN_TESTSUITES->all]);
    my @unknown = $lc->get_Lonly;

    my $control_position
      = $debian_control->source_fields->position('Testsuite');
    my $control_pointer = $debian_control->item->pointer($control_position);

    $self->pointed_hint('unknown-testsuite', $control_pointer, $_)for @unknown;

    my $tests_control
      = $self->processable->patched->resolve_path('debian/tests/control');

    # field added automatically since dpkg 1.17 when d/tests/control is present
    $self->pointed_hint('unnecessary-testsuite-autopkgtest-field',
        $control_pointer)
      if (any { $_ eq 'autopkgtest' } @testsuites) && defined $tests_control;

    # need d/tests/control for plain autopkgtest
    $self->pointed_hint('missing-tests-control', $control_pointer)
      if (any { $_ eq 'autopkgtest' } @testsuites) && !defined $tests_control;

    die encode_utf8('debian tests control is not a regular file')
      if defined $tests_control && !$tests_control->is_regular_file;

    if (defined $tests_control && $tests_control->is_valid_utf8) {

        # another check complains about invalid encoding
        my $contents = $tests_control->decoded_utf8;

        my $control_file = Lintian::Deb822->new;
        $control_file->parse_string($contents, DCTRL_COMMENTS_AT_EOL);

        my @sections = @{$control_file->sections};

        $self->pointed_hint('empty-debian-tests-control',
            $tests_control->pointer)
          unless @sections;

        $self->check_control_paragraph($tests_control, $_) for @sections;

        my @thorough
          = grep { $_->value('Restrictions') !~ m{\bsuperficial\b} } @sections;
        $self->pointed_hint('superficial-tests', $tests_control->pointer)
          if @sections && !@thorough;

        if (scalar @sections == 1) {

            my $section = $sections[0];

            my $command = $section->unfolded_value('Test-Command');
            my $position = $section->position('Test-Command');
            my $pointer = $tests_control->pointer($position);

            $self->pointed_hint('no-op-testsuite', $pointer)
              if $command =~ m{^ \s* (?:/bin/)? true \s* $}sx;
        }
    }

    my $control_autodep8
      = $self->processable->patched->resolve_path(
        'debian/tests/control.autodep8');
    $self->pointed_hint('debian-tests-control-autodep8-is-obsolete',
        $control_autodep8->pointer)
      if defined $control_autodep8;

    return;
}

sub check_control_paragraph {
    my ($self, $tests_control, $section) = @_;

    my $section_pointer = $tests_control->pointer($section->position);

    $self->pointed_hint('no-tests', $section_pointer)
      unless $section->declares('Tests') || $section->declares('Test-Command');

    $self->pointed_hint('conflicting-test-fields', $section_pointer, 'Tests',
        'Test-Command')
      if $section->declares('Tests') && $section->declares('Test-Command');

    my @lowercase_names = map { lc } $section->names;
    my @lowercase_known = map { lc } @KNOWN_FIELDS;

    my $lc = List::Compare->new(\@lowercase_names, \@lowercase_known);
    my @lowercase_unknown = $lc->get_Lonly;

    my @unknown = map { $section->literal_name($_) } @lowercase_unknown;
    $self->pointed_hint('unknown-runtime-tests-field',
        $tests_control->pointer($section->position($_)), $_)
      for @unknown;

    my @features = $section->trimmed_list('Features', qr/ \s* , \s* | \s+ /x);
    for my $feature (@features) {

        my $position = $section->position('Features');
        my $pointer = $tests_control->pointer($position);

        $self->pointed_hint('unknown-runtime-tests-feature',$pointer, $feature)
          unless exists $KNOWN_FEATURES{$feature}
          || $feature =~ m/^test-name=\S+/;
    }

    my $KNOWN_RESTRICTIONS= $self->data->load('testsuite/known-restrictions');
    my $KNOWN_OBSOLETE_RESTRICTIONS
      = $self->data->load('testsuite/known-obsolete-restrictions');

    my @restrictions
      = $section->trimmed_list('Restrictions', qr/ \s* , \s* | \s+ /x);
    for my $restriction (@restrictions) {

        my $position = $section->position('Restrictions');
        my $pointer = $tests_control->pointer($position);

        $self->pointed_hint('unknown-runtime-tests-restriction',
            $pointer, $restriction)
          unless $KNOWN_RESTRICTIONS->recognizes($restriction);

        $self->pointed_hint('obsolete-runtime-tests-restriction',
            $pointer, $restriction)
          if $KNOWN_OBSOLETE_RESTRICTIONS->recognizes($restriction);
    }

    my $test_command = $section->unfolded_value('Test-Command');

    # trim both sides
    $test_command =~ s/^\s+|\s+$//g;

    $self->pointed_hint('backgrounded-test-command',
        $tests_control->pointer($section->position('Test-Command')),
        $test_command)
      if $test_command =~ / & $/x;

    my $directory = $section->unfolded_value('Tests-Directory')
      || 'debian/tests';

    my $tests_position = $section->position('Tests');
    my $tests_pointer = $tests_control->pointer($tests_position);

    my @tests = uniq +$section->trimmed_list('Tests', qr/ \s* , \s* | \s+ /x);

    my @illegal_names = grep { !m{^ [ [:alnum:] \+ \- \. / ]+ $}x } @tests;
    $self->pointed_hint('illegal-runtime-test-name', $tests_pointer, $_)
      for @illegal_names;

    my @paths;
    if ($directory eq $DOT) {

        # Special case with "Tests-Directory: ." (see #849880)
        @paths = @tests;

    } else {
        @paths = map { "$directory/$_" } @tests;
    }

    my $debian_control = $self->processable->debian_control;

    my $depends_norestriction = Lintian::Relation->new;
    my $test_depends = $section->unfolded_value('Depends');
    if ($test_depends =~ /\@builddeps\@/) {
        my $build_depends
          = $debian_control->source_fields->unfolded_value('Build-Depends');
        my $build_depends_indep
          = $debian_control->source_fields->unfolded_value(
            'Build-Depends-Indep');
        my $build_depends_arch
          = $debian_control->source_fields->unfolded_value(
            'Build-Depends-Arch');
        my $all_build_deps = join(q{,},
            $build_depends, $build_depends_indep,
            $build_depends_arch, 'build-essential');

        $test_depends =~ s/\@builddeps\@/$all_build_deps/;
    }
    if ($test_depends =~ /\@recommends\@/) {
        my $package_recommends = q{};
        for my $installable ($debian_control->installables) {
            my $installable_fields
              = $debian_control->installable_fields($installable);
            my $installable_recommends
              = $installable_fields->unfolded_value('Recommends');
            if ($installable_recommends ne q{}) {
                $package_recommends .= ",$installable_recommends";
            }
        }
        $test_depends =~ s/\@recommends\@/$package_recommends/;
    }

    # Remove white-spaces
    $test_depends =~ s/\s+//g;
    # Remove multiple commas, which can be the
    # case due to substituting `@builddeps@,` or `@recommends@`
    $test_depends =~ s/,+/,/g;
    $depends_norestriction->load($test_depends);

    my $all_tests_use_supported = 1;

    for my $path (@paths) {

        my $item = $self->processable->patched->resolve_path($path);
        if (!defined $item) {

            $self->pointed_hint('missing-runtime-test-file', $tests_pointer,
                $path);
            next;
        }

        if (!$item->is_open_ok) {

            $self->pointed_hint('runtime-test-file-is-not-a-regular-file',
                $tests_pointer, $path);
            next;
        }

        my $queries_all_python_versions = 0;

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            my $pointer = $item->pointer($position);

            $self->pointed_hint('uses-deprecated-adttmp', $pointer)
              if $line =~ /ADTTMP/;

            if ($line =~ /(py3versions)((?:\s+--?\w+)*)/) {

                my $command = $1 . $2;
                my $options = $2;

                $self->pointed_hint(
                    'runtime-test-file-uses-installed-python-versions',
                    $pointer, $command)
                  if $options =~ /\s(?:-\w*i|--installed)/;

                $self->pointed_hint(
'runtime-test-file-uses-supported-python-versions-without-test-depends',
                    $pointer,
                    $command
                  )
                  if $options =~ /\s(?:-\w*s|--supported)/
                  && !$depends_norestriction->satisfies($PYTHON3_ALL_DEPEND);

                $self->pointed_hint('declare-python-versions-for-test',
                    $pointer, $command)
                  if $options =~ m{ \s (?: -\w*r | --requested ) }x
                  && !$debian_control->source_fields->declares(
                    'X-Python3-Version');

                $queries_all_python_versions = 1
                  if $options =~ m{ \s (?: -\w*s | --supported ) }x;
            }

        } continue {
            ++$position;
        }

        close $fd;

        $all_tests_use_supported = 0
          if !$queries_all_python_versions;

        $self->pointed_hint('test-leaves-python-version-untested',
            $item->pointer)
          if $depends_norestriction->satisfies($PYTHON3_ALL_DEPEND)
          && !$queries_all_python_versions;
    }

    if (   $debian_control->source_fields->declares('X-Python3-Version')
        && $all_tests_use_supported) {

        my $position
          = $debian_control->source_fields->position('X-Python3-Version');
        my $pointer = $debian_control->item->pointer($position);

        $self->pointed_hint('drop-python-version-declaration',$pointer);
    }

    if ($section->declares('Depends')) {

        my $depends = $section->unfolded_value('Depends');

        # trim both sides
        $depends =~ s/^\s+|\s+$//g;

        my $relation = Lintian::Relation->new->load($depends);

        # autopkgtest allows @ as predicate as an exception
        my @unparsable = grep { !exists $KNOWN_SPECIAL_DEPENDS{$_} }
          $relation->unparsable_predicates;

        my $position = $section->position('Depends');
        my $pointer = $tests_control->pointer($position);

        $self->pointed_hint('testsuite-dependency-has-unparsable-elements',
            $pointer, $DOUBLE_QUOTE . $_ . $DOUBLE_QUOTE)
          for @unparsable;

        my $OBSOLETE_PACKAGES
        = $self->data->load('fields/obsolete-packages',qr/\s*=>\s*/);

        for my $dep (split /\s*,\s*/, $depends) {
            my (@alternatives, @seen_obsolete_packages);

            push @alternatives, [_split_dep($_), $_]
              for (split /\s*\|\s*/, $dep);

            for my $part_d (@alternatives) {
                my ($d_pkg, $d_march, $d_version, undef, undef, $rest,
                    $part_d_orig)
                  = @{$part_d};

                push @seen_obsolete_packages, [$part_d_orig, $d_pkg]
                  if $OBSOLETE_PACKAGES->recognizes($d_pkg);
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
                        'testsuite-depends-on-obsolete-package',
                        "Depends: $dep${replacement}"
                    );
                } else {
                    $self->hint(
                        'testsuite-ored-depends-on-obsolete-package',
                        "Depends: $dep${replacement}"
                    );
                }
            }
        }
    }

    return;
}

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

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

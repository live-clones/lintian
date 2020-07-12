# testsuite -- lintian check script -*- perl -*-

# Copyright © 2013 Nicolas Boulenguez <nicolas@debian.org>
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>

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

package Lintian::testsuite;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use List::MoreUtils qw(any none);
use Path::Tiny;

use Lintian::Data;
use Lintian::Deb822::File;
use Lintian::Deb822::Parser qw(DCTRL_COMMENTS_AT_EOL);
use Lintian::Relation;

use constant EMPTY => q{};
use constant DOUBLE_QUOTE => q{"};

use Moo;
use namespace::clean;

with 'Lintian::Check';

my %KNOWN_FEATURES = map { $_ => 1 } qw();
my $KNOWN_FIELDS = Lintian::Data->new('testsuite/known-fields');
my $KNOWN_RESTRICTIONS = Lintian::Data->new('testsuite/known-restrictions');
my $KNOWN_OBSOLETE_RESTRICTIONS
  = Lintian::Data->new('testsuite/known-obsolete-restrictions');
my $KNOWN_TESTSUITES = Lintian::Data->new('testsuite/known-testsuites');

our $PYTHON3_ALL_DEPEND
  = 'python3-all:any | python3-all-dev:any | python3-all-dbg:any';

my %KNOWN_SPECIAL_DEPENDS = map { $_ => 1 } qw(
  @
  @builddeps@
);

sub source {
    my ($self) = @_;

    my $testsuite = $self->processable->source_field('Testsuite') // EMPTY;
    my @testsuites = split(/\s*,\s*/, $testsuite);

    my $lc = List::Compare->new(\@testsuites, [$KNOWN_TESTSUITES->all]);
    my @unknown = $lc->get_Lonly;

    $self->tag('unknown-testsuite', $_) for @unknown;

    my $tests_control
      = $self->processable->patched->resolve_path('debian/tests/control');

    # field added automatically since dpkg 1.17 when d/tests/control is present
    $self->tag('unnecessary-testsuite-autopkgtest-field')
      if (any { $_ eq 'autopkgtest' } @testsuites) && defined $tests_control;

    # need d/tests/control for plain autopkgtest
    $self->tag('missing-tests-control')
      if (any { $_ eq 'autopkgtest' } @testsuites) && !defined $tests_control;

    die 'debian tests control is not a regular file'
      if defined $tests_control && !$tests_control->is_regular_file;

    if (defined $tests_control && $tests_control->is_valid_utf8) {

        # another check complains about invalid encoding
        my $contents = $tests_control->decoded_utf8;

        my $control_file = Lintian::Deb822::File->new;
        $control_file->parse_string($contents, DCTRL_COMMENTS_AT_EOL);

        my @sections = @{$control_file->sections};

        $self->tag('empty-debian-tests-control')
          unless @sections;

        $self->check_control_paragraph($_) for @sections;

        if (scalar @sections == 1) {
            my $command = $sections[0]->unfolded_value('Test-Command')// EMPTY;
            $self->tag('no-op-testsuite')
              if $command =~ m{(?:/bin/)?true};
        }
    }

    my $control_autodep8
      = $self->processable->patched->resolve_path(
        'debian/tests/control.autodep8');
    $self->tag('debian-tests-control-autodep8-is-obsolete', $control_autodep8)
      if defined $control_autodep8;

    $self->tag('debian-tests-control-and-control-autodep8',
        $tests_control,$control_autodep8)
      if defined $tests_control && defined $control_autodep8;

    return;
}

sub check_control_paragraph {
    my ($self, $section) = @_;

    my $tests_field = $section->unfolded_value('Tests');
    my $test_command = $section->unfolded_value('Test-Command');

    die
"missing runtime tests field Tests || Test-Command, paragraph starting at line $line"
      unless defined $tests_field || defined $test_command;

    $self->tag(
        'exclusive-runtime-tests-field','tests, test-command',
        'paragraph starting at line', $section->position
    ) if defined $tests_field && defined $test_command;

    my @lowercase_names = map { lc } $section->names;
    my @lowercase_known = map { lc } $KNOWN_FIELDS->all;

    my $lc = List::Compare->new(\@lowercase_names, \@lowercase_known);
    my @lowercase_unknown = $lc->get_Lonly;

    my @unknown = map { $section->literal_name($_) } @lowercase_unknown;
    $self->tag('unknown-runtime-tests-field', $_,
        'in line', $section->position($_))
      for @unknown;

    my $features_field = $section->unfolded_value('Features');
    my @features
      = grep { length } split(/\s*,\s*|\s+/, $features_field // EMPTY);
    for my $feature (@features) {

        $self->tag('unknown-runtime-tests-feature',
            $feature,'in line', $section->position('Features'))
          unless exists $KNOWN_FEATURES{$feature}
          || $feature =~ m/^test-name=\S+/;
    }

    my $restrictions_field = $section->unfolded_value('Restrictions');
    my @restrictions
      = grep { length } split(/\s*,\s*|\s+/, $restrictions_field // EMPTY);
    for my $restriction (@restrictions) {

        my $line = $section->position('Restrictions');

        $self->tag('unknown-runtime-tests-restriction',
            $restriction,'in line', $line)
          unless $KNOWN_RESTRICTIONS->known($restriction);

        $self->tag('obsolete-runtime-tests-restriction',
            $restriction,'in line', $line)
          if $KNOWN_OBSOLETE_RESTRICTIONS->known($restriction);
    }

    my $directory = $section->unfolded_value('Tests-Directory')
      // 'debian/tests';

    my @tests = grep { length } split(/\s*,\s*|\s+/, $tests_field // EMPTY);

    $self->check_test_file($directory, $_, $section->position('Tests'))
      for @tests;

    my $depends = $section->unfolded_value('Depends');
    if (defined $depends) {

        # trim both sides
        $depends =~ s/^\s+|\s+$//g;

        my $relation = Lintian::Relation->new($depends);

        # autopkgtest allows @ as predicate as an exception
        my @unparsable = grep { !exists $KNOWN_SPECIAL_DEPENDS{$_} }
          $relation->unparsable_predicates;

        my $line = $section->position('Depends');
        $self->tag(
            'testsuite-dependency-has-unparsable-elements',
            DOUBLE_QUOTE . $_ . DOUBLE_QUOTE,
            "(in line $line)"
        )for @unparsable;
    }

    return;
}

sub check_test_file {
    my ($self, $directory, $name, $position) = @_;

    # Special case with "Tests-Directory: ." (see #849880)
    my $path = $directory eq '.' ? $name : "$directory/$name";

    $self->tag('illegal-runtime-test-name', $name,'in line', $position)
      unless $name =~ m{^ [ [:alnum:] \+ \- \. / ]+ $}x;

    my $file = $self->processable->patched->resolve_path($path);
    unless (defined $file) {
        $self->tag('missing-runtime-test-file', $path,'in line', $position);
        return;
    }

    unless ($file->is_open_ok) {
        $self->tag('runtime-test-file-is-not-a-regular-file', $path);
        return;
    }

    open(my $fd, '<', $file->unpacked_path);
    while (my $line = <$fd>) {

        $self->tag('uses-deprecated-adttmp', $path, "(line $.)")
          if $line =~ /ADTTMP/;

        if ($line =~ /(py3versions)((?:\s+--?\w+)*)/) {

            my $command = $1 . $2;
            my $options = $2;

            $self->tag('runtime-test-file-uses-installed-python-versions',
                $path, $command, "(line $.)")
              if $options =~ /\s(?:-\w*i|--installed)/;

            $self->tag(
'runtime-test-file-uses-supported-python-versions-without-python-all-build-depends',
                $path,
                $command,
                "(line $.)"
              )
              if $options =~ /\s(?:-\w*s|--supported)/
              && !$self->processable->relation_noarch('Build-Depends-All')
              ->implies($PYTHON3_ALL_DEPEND);
        }
    }

    close($fd);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

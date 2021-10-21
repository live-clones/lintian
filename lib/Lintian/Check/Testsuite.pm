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

package Lintian::Check::Testsuite;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any none uniq);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::File;
use Lintian::Deb822::Parser qw(DCTRL_COMMENTS_AT_EOL);
use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

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
);

sub source {
    my ($self) = @_;

    my $KNOWN_TESTSUITES
      = $self->profile->load_data('testsuite/known-testsuites');

    my $debian_control = $self->processable->debian_control;

    my $testsuite = $debian_control->source_fields->value('Testsuite');
    my @testsuites = split(/\s*,\s*/, $testsuite);

    my $lc = List::Compare->new(\@testsuites, [$KNOWN_TESTSUITES->all]);
    my @unknown = $lc->get_Lonly;

    $self->hint('unknown-testsuite', $_) for @unknown;

    my $tests_control
      = $self->processable->patched->resolve_path('debian/tests/control');

    # field added automatically since dpkg 1.17 when d/tests/control is present
    $self->hint('unnecessary-testsuite-autopkgtest-field')
      if (any { $_ eq 'autopkgtest' } @testsuites) && defined $tests_control;

    # need d/tests/control for plain autopkgtest
    $self->hint('missing-tests-control')
      if (any { $_ eq 'autopkgtest' } @testsuites) && !defined $tests_control;

    die encode_utf8('debian tests control is not a regular file')
      if defined $tests_control && !$tests_control->is_regular_file;

    if (defined $tests_control && $tests_control->is_valid_utf8) {

        # another check complains about invalid encoding
        my $contents = $tests_control->decoded_utf8;

        my $control_file = Lintian::Deb822::File->new;
        $control_file->parse_string($contents, DCTRL_COMMENTS_AT_EOL);

        my @sections = @{$control_file->sections};

        $self->hint('empty-debian-tests-control')
          unless @sections;

        $self->check_control_paragraph($_) for @sections;

        my @thorough
          = grep { $_->value('Restrictions') !~ m{\bsuperficial\b} } @sections;
        $self->hint('superficial-tests')
          if @sections && !@thorough;

        if (scalar @sections == 1) {
            my $command = $sections[0]->unfolded_value('Test-Command');

            $self->hint('no-op-testsuite')
              if $command =~ m{^ \s* (?:/bin/)? true \s* $}sx;
        }
    }

    my $control_autodep8
      = $self->processable->patched->resolve_path(
        'debian/tests/control.autodep8');
    $self->hint('debian-tests-control-autodep8-is-obsolete', $control_autodep8)
      if defined $control_autodep8;

    $self->hint('debian-tests-control-and-control-autodep8',
        $tests_control,$control_autodep8)
      if defined $tests_control && defined $control_autodep8;

    return;
}

sub check_control_paragraph {
    my ($self, $section) = @_;

    $self->hint('no-tests', 'line ' . $section->position)
      unless $section->declares('Tests') || $section->declares('Test-Command');

    $self->hint(
        'exclusive-runtime-tests-field','tests, test-command',
        'paragraph starting at line', $section->position
    ) if $section->declares('Tests') && $section->declares('Test-Command');

    my @lowercase_names = map { lc } $section->names;
    my @lowercase_known = map { lc } @KNOWN_FIELDS;

    my $lc = List::Compare->new(\@lowercase_names, \@lowercase_known);
    my @lowercase_unknown = $lc->get_Lonly;

    my @unknown = map { $section->literal_name($_) } @lowercase_unknown;
    $self->hint('unknown-runtime-tests-field', $_,
        'in line', $section->position($_))
      for @unknown;

    my @features = $section->trimmed_list('Features', qr/ \s* , \s* | \s+ /x);
    for my $feature (@features) {

        $self->hint('unknown-runtime-tests-feature',
            $feature,'in line', $section->position('Features'))
          unless exists $KNOWN_FEATURES{$feature}
          || $feature =~ m/^test-name=\S+/;
    }

    my $KNOWN_RESTRICTIONS
      = $self->profile->load_data('testsuite/known-restrictions');
    my $KNOWN_OBSOLETE_RESTRICTIONS
      = $self->profile->load_data('testsuite/known-obsolete-restrictions');

    my @restrictions
      = $section->trimmed_list('Restrictions', qr/ \s* , \s* | \s+ /x);
    for my $restriction (@restrictions) {

        my $line = $section->position('Restrictions');

        $self->hint('unknown-runtime-tests-restriction',
            $restriction,'in line', $line)
          unless $KNOWN_RESTRICTIONS->recognizes($restriction);

        $self->hint('obsolete-runtime-tests-restriction',
            $restriction,'in line', $line)
          if $KNOWN_OBSOLETE_RESTRICTIONS->recognizes($restriction);
    }

    my $test_command = $section->unfolded_value('Test-Command');

    # trim both sides
    $test_command =~ s/^\s+|\s+$//g;

    $self->hint('backgrounded-test-command', $test_command)
      if $test_command =~ / & $/x;

    my $directory = $section->unfolded_value('Tests-Directory')
      || 'debian/tests';

    my $position = $section->position('Tests');
    my @tests = uniq +$section->trimmed_list('Tests', qr/ \s* , \s* | \s+ /x);

    my @illegal_names = grep { !m{^ [ [:alnum:] \+ \- \. / ]+ $}x } @tests;
    $self->hint('illegal-runtime-test-name', $_, 'in line', $position)
      for @illegal_names;

    my @paths;
    if ($directory eq $DOT) {

        # Special case with "Tests-Directory: ." (see #849880)
        @paths = @tests;

    } else {
        @paths = map { "$directory/$_" } @tests;
    }

    for my $path (@paths) {

        $self->check_test_file($path, $position, $section);
    }

    if ($section->declares('Depends')) {

        my $depends = $section->unfolded_value('Depends');

        # trim both sides
        $depends =~ s/^\s+|\s+$//g;

        my $relation = Lintian::Relation->new->load($depends);

        # autopkgtest allows @ as predicate as an exception
        my @unparsable = grep { !exists $KNOWN_SPECIAL_DEPENDS{$_} }
          $relation->unparsable_predicates;

        my $line = $section->position('Depends');
        $self->hint(
            'testsuite-dependency-has-unparsable-elements',
            $DOUBLE_QUOTE . $_ . $DOUBLE_QUOTE,
            "(in line $line)"
        )for @unparsable;
    }

    return;
}

sub check_test_file {
    my ($self, $path, $position, $section) = @_;

    my $file = $self->processable->patched->resolve_path($path);
    unless (defined $file) {
        $self->hint('missing-runtime-test-file', $path, "(line $position)");
        return;
    }

    unless ($file->is_open_ok) {
        $self->hint('runtime-test-file-is-not-a-regular-file',
            $path, "(line $position)");
        return;
    }

    open(my $fd, '<', $file->unpacked_path)
      or die encode_utf8('Cannot open ' . $file->unpacked_path);

    while (my $line = <$fd>) {

        $self->hint('uses-deprecated-adttmp', $path, "(line $.)")
          if $line =~ /ADTTMP/;

        if ($line =~ /(py3versions)((?:\s+--?\w+)*)/) {

            my $command = $1 . $2;
            my $options = $2;

            $self->hint('runtime-test-file-uses-installed-python-versions',
                $path, $command, "(line $.)")
              if $options =~ /\s(?:-\w*i|--installed)/;

            my $depends_norestriction = Lintian::Relation->new;
            $depends_norestriction->load($section->unfolded_value('Depends'));

            $self->hint(
'runtime-test-file-uses-supported-python-versions-without-test-depends',
                $path,
                $command,
                "(line $.)"
              )
              if $options =~ /\s(?:-\w*s|--supported)/
              && !$depends_norestriction->satisfies($PYTHON3_ALL_DEPEND);
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

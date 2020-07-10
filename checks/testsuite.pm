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
use Lintian::Deb822Parser qw(
  DCTRL_COMMENTS_AT_EOL
  parse_dpkg_control_string
);
use Lintian::Relation;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# empty because it is test xor test-command
my @MANDATORY_FIELDS = qw();

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
        $self->check_control_contents($contents);
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

sub check_control_contents {
    my ($self, $contents) = @_;

    my $processable = $self->processable;

    my (@paragraphs, @lines);
    unless (
        eval {
            @paragraphs
              = parse_dpkg_control_string($contents, DCTRL_COMMENTS_AT_EOL,
                \@lines);
        }
    ) {
        chomp $@;
        $@ =~ s/^syntax error at //;
        die "syntax error in debian tests control $@"
          if length $@;
        $self->tag('empty-debian-tests-control');
    } else {
        while (my ($index, $paragraph) = each(@paragraphs)) {
            $self->check_control_paragraph($paragraph,
                $lines[$index]{'START-OF-PARAGRAPH'});
        }
        if (scalar(@paragraphs) == 1) {
            my $cmd = $paragraphs[0]->{'Test-Command'} // '';
            $self->tag('no-op-testsuite') if $cmd =~ m,^\s*(/bin/)?true,;
        }
    }
    return;
}

sub check_control_paragraph {
    my ($self, $paragraph, $line) = @_;

    my $processable = $self->processable;

    for my $fieldname (@MANDATORY_FIELDS) {
        if (not exists $paragraph->{$fieldname}) {
            die
"missing runtime tests field $fieldname, paragraph starting at line $line";
        }
    }

    unless (exists $paragraph->{'Tests'}
        || exists $paragraph->{'Test-Command'}) {
        die
"missing runtime tests field Tests || Test-Command, paragraph starting at line $line";
    }
    if (   exists $paragraph->{'Tests'}
        && exists $paragraph->{'Test-Command'}) {
        $self->tag(
            'exclusive-runtime-tests-field',
            'tests, test-command',
            'paragraph starting at line', $line
        );
    }

    for my $fieldname (sort(keys(%{$paragraph}))) {
        $self->tag(
            'unknown-runtime-tests-field', $fieldname,
            'paragraph starting at line', $line
        ) unless $KNOWN_FIELDS->known($fieldname);
    }

    if (exists $paragraph->{'Features'}) {
        my $features = $paragraph->{'Features'};
        for my $feature (split(/\s*,\s*|\s+/ms, $features)) {

            next
              unless length $feature;

            if (not exists $KNOWN_FEATURES{$feature}
                and $feature !~ m/^test-name=\S+/) {
                $self->tag(
                    'unknown-runtime-tests-feature', $feature,
                    'paragraph starting at line', $line
                );
            }
        }
    }

    if (exists $paragraph->{'Restrictions'}) {
        my $restrictions = $paragraph->{'Restrictions'};
        for my $restriction (split(/\s*,\s*|\s+/ms, $restrictions)) {
            next
              unless length $restriction;
            $self->tag(
                'unknown-runtime-tests-restriction', $restriction,
                'paragraph starting at line', $line
            ) unless $KNOWN_RESTRICTIONS->known($restriction);
            $self->tag('obsolete-runtime-tests-restriction',
                $restriction,'paragraph starting at line', $line)
              if $KNOWN_OBSOLETE_RESTRICTIONS->known($restriction);
        }
    }

    if (exists $paragraph->{'Tests'}) {
        my $tests = $paragraph->{'Tests'};
        my $directory = 'debian/tests';
        if (exists $paragraph->{'Tests-Directory'}) {
            $directory = $paragraph->{'Tests-Directory'};
        }
        for my $testname (split(/\s*,\s*|\s+/ms, $tests)) {

            next
              unless length $testname;

            $self->check_test_file($directory, $testname, $line);
        }
    }
    if (exists($paragraph->{'Depends'})) {
        my $depends = $paragraph->{'Depends'};
        $depends =~ s/^\s+|\s+$//g;
        my $dep = Lintian::Relation->new($depends);
        for my $unparsable ($dep->unparsable_predicates) {
            # @ is not a valid predicate in general, but autopkgtests
            # allows it.
            next if exists($KNOWN_SPECIAL_DEPENDS{$unparsable});
            $self->tag(
                'testsuite-dependency-has-unparsable-elements',
                "\"$unparsable\"",
                "(in paragraph starting at line $line)"
            );
        }
    }
    return;
}

sub check_test_file {
    my ($self, $directory, $name, $line) = @_;

    my $processable = $self->processable;

    # Special case with "Tests-Directory: ." (see #849880)
    my $path = $directory eq '.' ? $name : "$directory/$name";
    my $index = $processable->patched->resolve_path($path);

    if ($name !~ m{^ [ [:alnum:] \+ \- \. / ]++ $}xsm) {
        $self->tag(
            'illegal-runtime-test-name', $name,
            'paragraph starting at line', $line
        );
    }
    if (not defined($index)) {
        $self->tag(
            'missing-runtime-test-file', $path,
            'paragraph starting at line', $line
        );
    } elsif (not $index->is_open_ok) {
        $self->tag('runtime-test-file-is-not-a-regular-file', $path);
    } else {
        open(my $fd, '<', $index->unpacked_path);
        while (my $x = <$fd>) {
            $self->tag('uses-deprecated-adttmp', $path, "(line $.)")
              if $x =~ m/ADTTMP/;
            $self->tag('runtime-test-file-uses-installed-python-versions',
                $path, "$1", "(line $.)")
              if $x =~ m/(py3versions\s+([\w\-\s]*--installed|-\w*i\w*))/;
            #<<< no Perl tidy
            $self->tag(
                'runtime-test-file-uses-supported-python-versions-without-python-all-build-depends',
                $path, "$1", "(line $.)"
            ) if $x =~ m/(py3versions\s+([\w\-\s]*--supported|-\w*s\w*))/
              and not $processable->relation_noarch('Build-Depends-All')->implies($PYTHON3_ALL_DEPEND);
            #>>>
        }
        close($fd);
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# testsuite -- lintian check script -*- perl -*-

# Copyright (C) 2013 Nicolas Boulenguez <nicolas@debian.org>

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

use strict;
use warnings;
use autodie;

use Lintian::Data;
use Lintian::Deb822Parser qw(
  DCTRL_COMMENTS_AT_EOL
  read_dpkg_control
);
use Lintian::Relation;
use Lintian::Tags qw(tag);
use Lintian::Util qw(
  file_is_encoded_in_non_utf8
  strip
);

# empty because it is test xor test-command
my @MANDATORY_FIELDS = qw();

my %KNOWN_FEATURES = map { $_ => 1 } qw();
my $KNOWN_FIELDS = Lintian::Data->new('testsuite/known-fields');
my $KNOWN_RESTRICTIONS = Lintian::Data->new('testsuite/known-restrictions');
my $KNOWN_OBSOLETE_RESTRICTIONS
  = Lintian::Data->new('testsuite/known-obsolete-restrictions');
my $KNOWN_TESTSUITES = Lintian::Data->new('testsuite/known-testsuites');

my %KNOWN_SPECIAL_DEPENDS = map { $_ => 1 } qw(
  @
  @builddeps@
);

sub run {
    my ($pkg, $type, $info) = @_;
    my $testsuites = $info->field('testsuite', '');
    my $control = $info->index_resolved_path('debian/tests/control');
    my $control_autodep8
      = $info->index_resolved_path('debian/tests/control.autodep8');
    my $needs_control = 0;

    tag 'testsuite-autopkgtest-missing' if ($testsuites !~ /autopkgtest/);

    for my $testsuite (split(m/\s*,\s*/o, $testsuites)) {
        tag 'unknown-testsuite', $testsuite
          unless $KNOWN_TESTSUITES->known($testsuite);

        $needs_control = 1 if $testsuite eq 'autopkgtest';
    }
    if ($needs_control xor defined($control)) {
        tag 'inconsistent-testsuite-field';
    }

    if (defined($control)) {
        if (not $control->is_regular_file) {
            tag 'debian-tests-control-is-not-a-regular-file';
        } elsif ($control->is_open_ok) {
            my $path = $control->fs_path;
            my $not_utf8_line = file_is_encoded_in_non_utf8($path);

            if ($not_utf8_line) {
                tag 'debian-tests-control-uses-national-encoding',
                  "at line $not_utf8_line";
            }
            check_control_contents($info, $path);
        }

        tag 'unnecessary-testsuite-autopkgtest-field'
          if ($info->source_field('testsuite') // '') eq 'autopkgtest';

        tag 'debian-tests-control-and-control-autodep8', $control,
          $control_autodep8
          if defined($control_autodep8);
    }

    tag 'debian-tests-control-autodep8-is-obsolete', $control_autodep8
      if defined($control_autodep8);

    return;
}

sub check_control_contents {
    my ($info, $path) = @_;

    my (@paragraphs, @lines);
    if (
        not eval {
            @paragraphs
              = read_dpkg_control($path, DCTRL_COMMENTS_AT_EOL, \@lines);
        }
    ) {
        chomp $@;
        $@ =~ s/^syntax error at //;
        tag 'syntax-error-in-debian-tests-control', $@;
    } else {
        while (my ($index, $paragraph) = each(@paragraphs)) {
            check_control_paragraph($info, $paragraph,
                $lines[$index]{'START-OF-PARAGRAPH'});
        }
        if (scalar(@paragraphs) == 1) {
            my $cmd = $paragraphs[0]->{'test-command'} // '';
            tag 'no-op-testsuite' if $cmd =~ m,^\s*(/bin/)?true,;
        }
    }
    return;
}

sub check_control_paragraph {
    my ($info, $paragraph, $line) = @_;

    for my $fieldname (@MANDATORY_FIELDS) {
        if (not exists $paragraph->{$fieldname}) {
            tag 'missing-runtime-tests-field', $fieldname,
              'paragraph starting at line', $line;
        }
    }

    unless (exists $paragraph->{'tests'}
        || exists $paragraph->{'test-command'}) {
        tag 'missing-runtime-tests-field', 'tests || test-command',
          'paragraph starting at line', $line;
    }
    if (   exists $paragraph->{'tests'}
        && exists $paragraph->{'test-command'}) {
        tag 'exclusive-runtime-tests-field', 'tests, test-command',
          'paragraph starting at line', $line;
    }

    for my $fieldname (sort(keys(%{$paragraph}))) {
        tag 'unknown-runtime-tests-field', $fieldname,
          'paragraph starting at line', $line
          unless $KNOWN_FIELDS->known($fieldname);
    }

    if (exists $paragraph->{'features'}) {
        my $features = strip($paragraph->{'features'});
        for my $feature (split(/\s*,\s*|\s+/ms, $features)) {
            if (not exists $KNOWN_FEATURES{$feature}
                and $feature !~ m/^test-name=\S+/) {
                tag 'unknown-runtime-tests-feature', $feature,
                  'paragraph starting at line', $line;
            }
        }
    }

    if (exists $paragraph->{'restrictions'}) {
        my $restrictions = strip($paragraph->{'restrictions'});
        for my $restriction (split(/\s*,\s*|\s+/ms, $restrictions)) {
            tag 'unknown-runtime-tests-restriction', $restriction,
              'paragraph starting at line', $line
              unless $KNOWN_RESTRICTIONS->known($restriction);
            tag 'obsolete-runtime-tests-restriction', $restriction,
              'paragraph starting at line', $line
              if $KNOWN_OBSOLETE_RESTRICTIONS->known($restriction);
        }
    }

    if (exists $paragraph->{'tests'}) {
        my $tests = strip($paragraph->{'tests'});
        my $directory = 'debian/tests';
        if (exists $paragraph->{'tests-directory'}) {
            $directory = $paragraph->{'tests-directory'};
        }
        for my $testname (split(/\s*,\s*|\s+/ms, $tests)) {
            check_test_file($info, $directory, $testname, $line);
        }
    }
    if (exists($paragraph->{'depends'})) {
        my $dep = Lintian::Relation->new(strip($paragraph->{'depends'}));
        for my $unparsable ($dep->unparsable_predicates) {
            # @ is not a valid predicate in general, but autopkgtests
            # allows it.
            next if exists($KNOWN_SPECIAL_DEPENDS{$unparsable});
            tag 'testsuite-dependency-has-unparsable-elements',
              "\"$unparsable\"",
              "(in paragraph starting at line $line)";
        }
    }
    return;
}

sub check_test_file {
    my ($info, $directory, $name, $line) = @_;
    # Special case with "Tests-Directory: ." (see #849880)
    my $path = $directory eq '.' ? $name : "$directory/$name";
    my $index = $info->index_resolved_path($path);

    if ($name !~ m{^ [ [:alnum:] \+ \- \. / ]++ $}xsm) {
        tag 'illegal-runtime-test-name', $name,
          'paragraph starting at line', $line;
    }
    if (not defined($index)) {
        tag 'missing-runtime-test-file', $path,
          'paragraph starting at line', $line;
    } elsif (not $index->is_open_ok) {
        tag 'runtime-test-file-is-not-a-regular-file', $path;
    }
    # Test files are allowed not to be executable.
    return;
}

1;

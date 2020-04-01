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

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Data;
use Lintian::Deb822Parser qw(
  DCTRL_COMMENTS_AT_EOL
  read_dpkg_control
);
use Lintian::Relation;
use Lintian::Util qw(
  file_is_encoded_in_non_utf8
  strip
);

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

my %KNOWN_SPECIAL_DEPENDS = map { $_ => 1 } qw(
  @
  @builddeps@
);

sub source {
    my ($self) = @_;

    my $pkg = $self->package;
    my $type = $self->type;
    my $processable = $self->processable;

    my $testsuites = $processable->field('testsuite', '');
    my $control = $processable->patched->resolve_path('debian/tests/control');
    my $control_autodep8
      = $processable->patched->resolve_path('debian/tests/control.autodep8');
    my $needs_control = 0;

    $self->tag('testsuite-autopkgtest-missing')
      if ($testsuites !~ /autopkgtest/);

    for my $testsuite (split(m/\s*,\s*/o, $testsuites)) {
        $self->tag('unknown-testsuite', $testsuite)
          unless $KNOWN_TESTSUITES->known($testsuite);

        $needs_control = 1 if $testsuite eq 'autopkgtest';
    }
    if ($needs_control xor defined($control)) {
        $self->tag('inconsistent-testsuite-field');
    }

    if (defined($control)) {
        if (not $control->is_regular_file) {
            die 'debian tests control is not a regular file';
        } elsif ($control->is_open_ok) {
            my $path = $control->unpacked_path;
            my $not_utf8_line = file_is_encoded_in_non_utf8($path);

            if ($not_utf8_line) {
                $self->tag('debian-tests-control-uses-national-encoding',
                    "at line $not_utf8_line");
            }
            $self->check_control_contents($path);
        }

        $self->tag('unnecessary-testsuite-autopkgtest-field')
          if ($processable->source_field('testsuite') // '') eq 'autopkgtest';

        $self->tag('debian-tests-control-and-control-autodep8',
            $control,$control_autodep8)
          if defined($control_autodep8);
    }

    $self->tag('debian-tests-control-autodep8-is-obsolete', $control_autodep8)
      if defined($control_autodep8);

    return;
}

sub check_control_contents {
    my ($self, $path) = @_;

    my $processable = $self->processable;

    my (@paragraphs, @lines);
    if (
        not eval {
            @paragraphs
              = read_dpkg_control($path, DCTRL_COMMENTS_AT_EOL, \@lines);
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
            my $cmd = $paragraphs[0]->{'test-command'} // '';
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

    unless (exists $paragraph->{'tests'}
        || exists $paragraph->{'test-command'}) {
        die
"missing runtime tests field tests || test-command, paragraph starting at line $line";
    }
    if (   exists $paragraph->{'tests'}
        && exists $paragraph->{'test-command'}) {
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

    if (exists $paragraph->{'features'}) {
        my $features = strip($paragraph->{'features'});
        for my $feature (split(/\s*,\s*|\s+/ms, $features)) {
            if (not exists $KNOWN_FEATURES{$feature}
                and $feature !~ m/^test-name=\S+/) {
                $self->tag(
                    'unknown-runtime-tests-feature', $feature,
                    'paragraph starting at line', $line
                );
            }
        }
    }

    if (exists $paragraph->{'restrictions'}) {
        my $restrictions = strip($paragraph->{'restrictions'});
        for my $restriction (split(/\s*,\s*|\s+/ms, $restrictions)) {
            $self->tag(
                'unknown-runtime-tests-restriction', $restriction,
                'paragraph starting at line', $line
            ) unless $KNOWN_RESTRICTIONS->known($restriction);
            $self->tag('obsolete-runtime-tests-restriction',
                $restriction,'paragraph starting at line', $line)
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
            $self->check_test_file($directory, $testname, $line);
        }
    }
    if (exists($paragraph->{'depends'})) {
        my $dep = Lintian::Relation->new(strip($paragraph->{'depends'}));
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
              and not $processable->relation('build-depends-all')->implies('python3-all');
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

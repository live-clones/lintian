#!/usr/bin/perl

# Copyright © 2019 Felix Lechner
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

# The harness for Lintian's test suite.  For detailed information on
# the test suite layout and naming conventions, see t/tests/README.
# For more information about running tests, see
# doc/tutorial/Lintian/Tutorial/TestSuite.pod
#

use strict;
use warnings;
use v5.10;

use Const::Fast;
use File::Basename;
use File::Find::Rule;
use List::Compare;
use List::SomeUtils qw(uniq);
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";

use Lintian::Profile;
use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Output::EWI qw(to_universal);
use Test::Lintian::Output::Universal qw(tag_name);

const my $SPACE => q{ };
const my $NEWLINE => qq{\n};

my @known_missing = (qw(
      changed-by-invalid-for-derivative
      crossing-screens
      debian-files-list-in-source
      debian-rules-not-executable
      embedded-pear-module
      invalid-field-for-derivative
      invalid-version-number-for-derivative
      manual-page-in-udeb
      no-tests
      old-python-version-field
      old-source-override-location
      patch-modifying-debian-files
      patch-system-but-direct-changes-in-diff
      quilt-series-references-non-existent-patch
      source-contains-quilt-control-dir
      sphinxdoc-but-no-sphinxdoc-depends
      unpack-message-for-deb-control
      unpack-message-for-orig
      uses-deprecated-adttmp
      ),

# the following tags are not testable due to restrictions in reprotest
# building the tests causes regressions due to an unknown problem, maybe in docker
# possibly related to https://github.com/yarnpkg/yarn/pull/1837
# their functionality is probably better tested in piuparts
    qw(
      wrong-file-owner-uid-or-gid
      bad-owner-for-doc-file
      non-standard-game-executable-perm
      rules-silently-require-root
));

my $profile = Lintian::Profile->new;
$profile->load(undef, undef, 0);

# find known checks
my @known = uniq $profile->known_checks;

my %checktags;
$checktags{$_} = $profile->tagnames_for_check->{$_}for @known;

my %seen;

my @descpaths = File::Find::Rule->file()->name('desc')->in('t/recipes');
for my $descpath (@descpaths) {

    my $testcase = read_config($descpath);

    my $testpath = dirname($descpath);
    my $hintspath = "$testpath/hints";

    next unless -r $hintspath;

    my $universal = path($hintspath)->slurp_utf8;

    print "testcase->{testname}\n";
    my @lines = split(/$NEWLINE/, $universal);
    my @testfor = uniq map { tag_name($_) } @lines;

    #    diag "Test-For: " . join($SPACE, @testfor);

    if (exists $testcase->{check}) {
        my @checks = split($SPACE, $testcase->{check});
        #        diag "Checks: " . join($SPACE, @checks);
        my @related;
        push(@related, @{$checktags{$_} // []})for @checks;
        my $lc = List::Compare->new(\@testfor, \@related);
        @testfor = $lc->get_intersection;
    }

    $seen{$_} = 1 for @testfor;
}

# find known tags
my @wanted = uniq $profile->known_tags;
my $total = scalar @wanted;

# set the testing plan
plan tests => scalar @wanted + 2;

for my $name (@wanted) {
  TODO: {
        local $TODO = "Tag $name is currently untested"
          unless exists $seen{$name};

        ok(exists $seen{$name}, "Tag $name appears in tests");
    }
}

my @tested = keys %seen;

my $comp = List::Compare->new(\@wanted, \@tested);
my @missing = $comp->get_Lonly;
my @extra = $comp->get_Ronly;

my $found = scalar @tested;
diag 'Missing '
  . scalar @missing
  . " out of $total tags for complete test coverage.";

diag "Untested tag: $_" for @missing;
#diag "Extra: $_" for @extra;

my $exceptions = List::Compare->new(\@missing, \@known_missing);
my @unknown = $exceptions->get_Lonly;
my @solved = $exceptions->get_Ronly;

is(scalar @unknown, 0, 'All tags are covered in the testsuite');
diag "Unknown/missing tag: $_" for @unknown;

is(scalar @solved, 0, 'Solved tags should be removed from known missing set');
diag "Solved tag: $_" for @solved;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

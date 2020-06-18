#!/usr/bin/perl

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

# The harness for Lintian's test suite.  For detailed information on
# the test suite layout and naming conventions, see t/tests/README.
# For more information about running tests, see
# doc/tutorial/Lintian/Tutorial/TestSuite.pod
#

use strict;
use warnings;
use autodie;
use v5.10;

use File::Find::Rule;
use List::Compare;
use List::MoreUtils qw(uniq);
use Path::Tiny;
use Test::More;

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Output::Universal qw(tag_name);

use constant SPACE => q{ };
use constant EMPTY => q{};

my @known_undeclared = qw(
  t/recipes/checks/binaries/binaries-unsafe-open
  t/recipes/checks/changes-file/changelog-file-backport
  t/recipes/checks/debian/changelog/changelog-version-bzr
  t/recipes/checks/debian/copyright/patch-empties-directory
  t/recipes/checks/debian/upstream/signing-key/upstream-key-minimal
  t/recipes/checks/debian/upstream/signing-key/upstream-keyring
  t/recipes/checks/fields/section/generic-empty
  t/recipes/checks/fields/section/legacy-filenames
  t/recipes/checks/fields/standards-version/generic-empty
  t/recipes/checks/fields/urgency/changelog-file-backport
  t/recipes/checks/fields/urgency/changes-bad-ubuntu-distribution
  t/recipes/checks/fields/urgency/changes-distribution-mismatch
  t/recipes/checks/fields/urgency/changes-experimental-mismatch
  t/recipes/checks/fields/urgency/changes-file-bad-section
  t/recipes/checks/fields/urgency/changes-file-size-checksum-mismatch
  t/recipes/checks/fields/urgency/changes-files-package-builds-dbg-and-dbgsym-variants
  t/recipes/checks/fields/urgency/changes-missing-fields
  t/recipes/checks/fields/urgency/changes-missing-format
  t/recipes/checks/fields/urgency/changes-unreleased
  t/recipes/checks/fields/urgency/changes-upload-has-backports-version-number
  t/recipes/checks/fields/urgency/checksum-count-mismatch
  t/recipes/checks/fields/urgency/distribution-multiple-bad
  t/recipes/checks/fields/urgency/legacy-foo++
  t/recipes/checks/fields/urgency/watch-file-pgpmode-next
  t/recipes/checks/fields/version/fields-general-missing
  t/recipes/checks/mailcap/unquoted-placeholder
);

my @descpaths = File::Find::Rule->file()->name('desc')->in('t/recipes/checks');

my @testpaths;
for my $descpath (@descpaths) {

    my $testpath = path($descpath)->parent->parent->stringify;
    my $tagspath = "$testpath/eval/tags";

    push(@testpaths, $testpath)
      if -r $tagspath;
}

# set the testing plan
plan tests => scalar @testpaths + 2;

my @undeclared;
for my $testpath (@testpaths) {

    my $descpath = "$testpath/eval/desc";
    my $tagspath = "$testpath/eval/tags";

    my $testcase = read_config($descpath);
    my @testagainst = uniq split(SPACE, $testcase->{test_against} // EMPTY);

    my @lines = path($tagspath)->lines_utf8({ chomp => 1 });
    my @testfor = uniq map { tag_name($_) } @lines;

    my @combined = (@testfor, @testagainst);

    push(@undeclared, $testpath) unless scalar @combined;

  TODO: {
        local $TODO = "Recipe does not test for or against tags in $testpath"
          unless scalar @combined;

        ok(scalar @combined, "Recipe tests for or against tags in $testpath");
    }
}

my $missing = scalar @undeclared;
my $total = scalar @testpaths;
diag "$missing tests out of $total have no declared diagnostic value.";

diag "Test with unknown purpose: $_" for @undeclared;

my $exceptions = List::Compare->new(\@undeclared, \@known_undeclared);
my @unknown = $exceptions->get_Lonly;
my @solved = $exceptions->get_Ronly;

is(scalar @unknown, 0, 'All tests without a declared purpose are known');
diag "Unknown/missing test: $_" for @unknown;

is(scalar @solved,0,'Solved test should be removed from known undeclared set');
diag "Solved test: $_" for @solved;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

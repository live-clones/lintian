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
use v5.10;

use File::Find::Rule;
use List::Compare;
use List::SomeUtils qw(uniq);
use Path::Tiny;
use Test::More;

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Output::Universal qw(tag_name);

my @known_undeclared = qw(
);

my @descpaths = File::Find::Rule->file()->name('desc')->in('t/recipes/checks');

my @testpaths;
for my $descpath (@descpaths) {

    my $testpath = path($descpath)->parent->parent->stringify;
    my $hintspath = "$testpath/eval/hints";

    push(@testpaths, $testpath)
      if -r $hintspath;
}

# set the testing plan
plan tests => scalar @testpaths + 2;

my @undeclared;
for my $testpath (@testpaths) {

    my $descpath = "$testpath/eval/desc";
    my $hintspath = "$testpath/eval/hints";

    my $testcase = read_config($descpath);
    my @testagainst = uniq $testcase->trimmed_list('Test-Against');

    my @lines = path($hintspath)->lines_utf8({ chomp => 1 });
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
diag "New test without a declared purpose: $_" for @unknown;

is(scalar @solved,0,'Solved test should be removed from known undeclared set');
diag "Solved test: $_" for @solved;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

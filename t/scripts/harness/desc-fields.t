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

use Const::Fast;
use File::Find::Rule;
use List::SomeUtils qw(uniq);
use List::Util qw(all);
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";

use Lintian::Profile;
use Test::Lintian::ConfigFile qw(read_config);

const my $FIXED_TESTS_PER_FILE => 6;

my @descpaths = File::Find::Rule->file()->name('desc')->in('t/recipes');

# mandatory fields
my @mandatory = qw(Testname);

# disallowed fields
my @disallowed = qw(Test-For Checks References Reference Ref);

# tests per desc
my $perfile = $FIXED_TESTS_PER_FILE + scalar @mandatory + scalar @disallowed;

# set the testing plan
my $known_tests = $perfile * scalar @descpaths;

my $profile = Lintian::Profile->new;
$profile->load(undef, undef, 0);

for my $descpath (@descpaths) {

    # test for duplicate fields
    my %count;
    my @lines = path($descpath)->lines_utf8;
    for my $line (@lines) {
        my ($field) = $line =~ qr/^(\S+):/;
        $count{$field} += 1
          if defined $field;
    }
    ok(
        (all { $count{$_} == 1 } keys %count),
        "No duplicate fields in $descpath"
    );

    my $testcase = read_config($descpath);

    # get test path
    my $testpath = path($descpath)->parent->parent->stringify;

    # get name from encapsulating directory
    my $name = path($testpath)->basename;

    # name equals encapsulating directory
    is($testcase->unfolded_value('Testname'),
        $name, "Test name matches encapsulating directory in $testpath");

    # mandatory fields
    ok($testcase->declares($_), "Field $_ exists in $name") for @mandatory;

    # disallowed fields
    ok(!$testcase->declares($_), "Field $_ does not exist in $name")
      for @disallowed;

    # no test-against without check
    ok(!$testcase->declares('Test-Against') || $testcase->declares('Check'),
        "No Test-Against without Check in $name");

    # get checks
    my @check_names = $testcase->trimmed_list('Check');

    # no duplicates in checks
    is(
        (scalar @check_names),
        (scalar uniq @check_names),
        "No duplicates in Check in $name"
    );

    # listed checks exist
    ok((all { length $profile->check_module_by_name->{$_} } @check_names),
        "All checks mentioned in $testpath exist");

    # no duplicates in tags against
    my @against = $testcase->trimmed_list('Test-Against');
    is(
        (scalar @against),
        (scalar uniq @against),
        "No duplicates in Test-Against in $name"
    );

    # listed test-against belong to listed checks
    $known_tests += scalar @against;
    my @tags = map { @{$profile->tagnames_for_check->{$_} // []} }
      (@check_names, 'lintian');
    my %relatedtags = map { $_ => 1 } @tags;
    for my $tag (@against) {
        ok(
            exists $relatedtags{$tag},
            "Tags $tag in Test-Against belongs to checks listed in $testpath"
        );
    }
}

done_testing($known_tests);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

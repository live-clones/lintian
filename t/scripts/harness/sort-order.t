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

use File::Basename;
use File::Find::Rule;
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";

use Lintian::Profile;
use Test::Lintian::ConfigFile qw(read_config);

my $checkpath = 't/recipes/checks';

# find all test specifications related to only one check
my @descpaths = sort File::Find::Rule->file()->name('desc')->in($checkpath);

# set the testing plan
plan tests => 3 * scalar @descpaths;

my $profile = Lintian::Profile->new;
$profile->load(undef, undef, 0);

foreach my $descpath (@descpaths) {

    my $testcase = read_config($descpath);
    my $name = $testcase->unfolded_value('Testname');

    # get test path
    my $testpath = path($descpath)->parent->stringify;

    ok($testcase->declares('Check'),
        "Test specification for $name defines a field Check");

    next
      unless $testcase->declares('Check');

    my @checks = $testcase->trimmed_list('Check');

    # test is only about one check
    is(scalar @checks, 1,"Test in $testpath is associate only with one check");

    next unless scalar @checks == 1;
    my $check = $checks[0];

    # get the relative location of folder containing test
    my $parent = path($testpath)->parent->parent;
    my $relative = $parent->relative($checkpath)->stringify;

    # relative location should match check
    is($relative, $check,
        "Test in $testpath is located in correct folder ($relative != $check)"
    );
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

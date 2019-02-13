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
use autodie;
use v5.10;

use File::Basename;
use File::Find::Rule;
use File::Spec::Functions qw(rel2abs splitpath splitdir);
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_TEST_ROOT'}/lib";

use Lintian::Profile;
use Test::Lintian::ConfigFile qw(read_config);

use constant SPACE => q{ };
use constant EMPTY => q{};

my $checkpath = 't/tags/checks';

# find all immediate directories under t/tags/checks
my @folders = map { $_ if -d $_ } path($checkpath)->children;

# find all test specifications related to only one check
my @descpaths = File::Find::Rule->file()->name('desc')->in($checkpath);

# set the testing plan
plan tests => scalar @folders + 3 * scalar @descpaths;

# needed for folder name calculation
my (undef, $directories, undef) = splitpath(rel2abs($checkpath));
my $depth = scalar splitdir($directories);

my $profile = Lintian::Profile->new(undef, [$ENV{LINTIAN_ROOT}]);

# make sure the folders correspond to valid Lintian checks
ok($profile->get_script(basename($_)),
    "Folder $_ corresponds to a valid Lintian check")
  for @folders;

foreach my $descpath (@descpaths) {

    my $testcase = read_config($descpath);
    my $name = $testcase->{testname};

    # get test path
    my $testpath = path($descpath)->parent->stringify;

    ok(defined $testcase->{check},
        "Test specification for $name defines a field Check");

    next unless defined $testcase->{check};
    my @checks = split(SPACE, $testcase->{check});

    # test is only about one check
    is(scalar @checks, 1,"Test in $testpath is associate only with one check");

    next unless scalar @checks == 1;
    my $check = $checks[0];

    # get the name of the folder under checks
    my (undef, $directories, undef) = splitpath(rel2abs($descpath));
    my $folder = (splitdir($directories))[$depth];

    # make first-level child directory matches name of the check
    is($folder, $check, "Test in $testpath is located in correct folder");
}

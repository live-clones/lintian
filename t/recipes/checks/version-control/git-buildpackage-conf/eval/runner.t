#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

# Basic test for git-buildpackage configuration detection
my $testname = 'version-control/git-buildpackage-conf';

# Check if gbp.conf exists in the test package
ok(-f "t/recipes/checks/version-control/git-buildpackage-conf/build-spec/debian/gbp.conf",
    'gbp.conf exists');

# Check if the tag file exists
ok(-f "tags/u/uses-gbp-conf.tag",
    'uses-gbp-conf tag is defined');

done_testing;

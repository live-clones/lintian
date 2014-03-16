#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Lintian;
use Test::More;
plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};
eval 'use Test::MinimumVersion';
plan skip_all => 'Test::MinimumVersion required to run this test' if $@;

# squeeze => 5.10.1, Wheezy => 5.14.2
our $REQUIRED = 'v5.14.2';

my @test_paths = program_name_to_perl_paths($0);
$ENV{'LINTIAN_TEST_ROOT'} //= '.';

all_minimum_version_ok($REQUIRED, { paths => \@test_paths, no_plan => 1});

done_testing();

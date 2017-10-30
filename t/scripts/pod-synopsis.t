#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};
eval 'use Test::Pod';
plan skip_all => 'Test::Pod required for testing' if $@;
eval 'use Test::Synopsis';
plan skip_all => 'Test::Synopsis required for testing' if $@;

$ENV{'LINTIAN_TEST_ROOT'} //= '.';

my @pod_files = all_pod_files("$ENV{'LINTIAN_TEST_ROOT'}/lib");
plan tests => scalar(@pod_files);
synopsis_ok(@pod_files);

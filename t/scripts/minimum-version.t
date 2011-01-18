#!/usr/bin/perl -w

use Test::More;
eval 'use Test::MinimumVersion';
plan skip_all => 'Test::MinimumVersion required to run this test' if $@;

# sarge was released with 5.8.4, etch with 5.8.8, lenny with 5.10.0
all_minimum_version_ok('v5.10.0', { paths => [$ENV{'LINTIAN_ROOT'}] });

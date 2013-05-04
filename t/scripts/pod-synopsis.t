#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Pod;
eval 'use Test::Synopsis';
plan skip_all => 'Test::Synopsis required for testing' if $@;

$ENV{'LINTIAN_ROOT'} //= '.';

my @pod_files = all_pod_files("$ENV{'LINTIAN_ROOT'}/lib");
plan tests => scalar(@pod_files);
synopsis_ok(@pod_files);

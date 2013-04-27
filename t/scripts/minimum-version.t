#!/usr/bin/perl -w

use strict;
use warnings;

# Poor man's attempt to speed up this test:
# (needs to be loaded before anything else)
use threads;

use Test::More;
eval 'use Test::MinimumVersion';
plan skip_all => 'Test::MinimumVersion required to run this test' if $@;

# sarge was released with 5.8.4, etch with 5.8.8, lenny with 5.10.0
our $REQUIRED = 'v5.10.0';

our @PATHS = qw(checks collection frontend lib reporting private);

# It creates as many threads as elements in @PATHS
for my $path (@PATHS) {
    threads->create(sub {
	my $p = shift;
	$p = $ENV{'LINTIAN_ROOT'} . '/' . $p;
	all_minimum_version_ok($REQUIRED, { paths => [$p] , no_plan => 1});
    }, $path);
}

for my $thr (threads->list()) {
    $thr->join();
}

done_testing();

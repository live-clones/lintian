#!/usr/bin/perl -w

use strict;
use warnings;

# Poor man's attempt to speed up this test:
# (needs to be loaded before anything else)
use threads;

use Test::More;
eval 'use Test::MinimumVersion';
plan skip_all => 'Test::MinimumVersion required to run this test' if $@;

# squeeze => 5.10.1, Wheezy => 5.14.2
our $REQUIRED = 'v5.14.2';

our @PATHS = qw(checks collection commands frontend lib reporting private);

$ENV{'LINTIAN_TEST_ROOT'} //= '.';

# It creates as many threads as elements in @PATHS
for my $path (@PATHS) {
    threads->create(
        sub {
            my $p = shift;
            $p = $ENV{'LINTIAN_TEST_ROOT'} . '/' . $p;
            all_minimum_version_ok($REQUIRED, { paths => [$p], no_plan => 1});
        },
        $path
    );
}

for my $thr (threads->list()) {
    $thr->join();
}

done_testing();

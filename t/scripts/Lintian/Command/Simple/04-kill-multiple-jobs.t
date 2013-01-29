#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Command::Simple qw(background kill_all wait_any);

my $c = 4;
my %jobs;

while ($c) {
    my $pid = background ('sleep', 10);
    $jobs{$pid} = $1;
    $c--;
}

is(kill_all (\%jobs), 4, '4 jobs were killed');

is(wait_any (\%jobs), undef, 'kill(hashref) kills and reaps');

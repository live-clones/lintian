#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 22;

use Lintian::Command::Simple qw(background wait_any);

my $c = 4;
my %jobs;

while ($c) {
    my $pid = background('sleep', 1);
    $jobs{$pid} = 'value';
    $c--;
}

while (my $value = wait_any(\%jobs)) {
    is($?, 0, 'One job terminated successfully');
    is($value, 'value', 'wait_any returned the value');
    $c++;
}

is($c, 4, '4 jobs were started, 4 reaped');

# again, but in list context

while ($c) {
    my $pid = background('sleep', 1);
    $jobs{$pid} = "value $pid";
    $c--;
}

while (my ($pid, $value) = wait_any(\%jobs)) {
    is($?, 0, "Pid $pid terminated successfully");
    is($value, "value $pid", 'wait_any returned the right value');
    $c++;
}

is($c, 4, '4 more jobs were started, 4 reaped');

# Make sure the case of an empty hash is handled properly
# (i.e. undef is returned and no process is reaped)

%jobs = ();
my $pid = background('true');
is(wait_any(\%jobs), undef, 'With an empty hash ref, wait() returns undef');

is(my @list = wait_any(\%jobs),
    0,'With an empty hash ref, in list context wait() returns null');

is(waitpid($pid, 0), $pid, 'Reap successful');
is($?, 0, 'Child returned successfully');


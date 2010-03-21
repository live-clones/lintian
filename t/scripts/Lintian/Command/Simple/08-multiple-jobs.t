#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;

use Lintian::Command::Simple;

my $cmd;
my $c = 4;
my %jobs;

while ($c) {
    $cmd = Lintian::Command::Simple->new();
    $cmd->fork("sleep", 1);
    $jobs{$c} = $cmd;
    $c--;
}

while ($cmd = Lintian::Command::Simple::wait(\%jobs)) {
    is($cmd->status(), 0, "One job terminated successfully");
    $c++;
}

is($c, 4, "4 jobs were started, 4 reaped");

# again, but in list context

while ($c) {
    $cmd = Lintian::Command::Simple->new();
    $cmd->fork("sleep", 1);
    $jobs{"Job $c"} = $cmd;
    $c--;
}

my $name;
while (($name, $cmd) = Lintian::Command::Simple::wait(\%jobs)) {
    is($cmd->status(), 0, "$name terminated successfully");
    $c++;
}

is($c, 4, "4 more jobs were started, 4 reaped");

# Make sure the case of an empty hash is handled properly
# (i.e. undef is returned and no process is reaped)

%jobs = ();
my $pid = Lintian::Command::Simple::fork("true");
is(Lintian::Command::Simple::wait(\%jobs), undef,
    "With an empty hash ref, wait() returns undef");

is(Lintian::Command::Simple::wait($pid), 0,
    "With an empty hash ref, wait() doesn't reap");

# Again but now in list context

%jobs = ();
$pid = Lintian::Command::Simple::fork("true");
is(my @list = Lintian::Command::Simple::wait(\%jobs), 0,
    "With an empty hash ref, in list context wait() returns null");



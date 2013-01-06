#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 17;

use Lintian::Command::Simple;

my ($cmd, $pid);

# Run a command via the procedural interface and make sure calling the
# OO's interface wait() doesn't reap it (because the OO interface
# should only deal with any command started with it)

$pid = Lintian::Command::Simple::background("true");

$cmd = Lintian::Command::Simple->new();

is($cmd->wait(), -1, "No job via OO interface, wait() returns -1");

is(Lintian::Command::Simple::wait($pid), 0, "Checking \$? of the started child");

# Run two commands in a row on the same object, without wait()ing

$cmd = Lintian::Command::Simple->new();

cmp_ok($cmd->background("true"), '>', 0, 'Running one job is ok');
is($cmd->background("false"), -1, 'Running a second job is not');

is($cmd->wait(), 0, "We wait() for the 'true' job");
is(Lintian::Command::Simple::wait(), -1, "No other job is running");

# Run two commands in a row on the same object, wait()ing

$cmd = Lintian::Command::Simple->new();

cmp_ok($cmd->background("true"), '>', 0, 'Running one job is ok');
is($cmd->wait(), 0, "We wait() for the 'true' job");

cmp_ok($cmd->background("false"), '>', 0, 'Running a second job is ok after wait()ing');
is($cmd->wait(), 1, "We wait() for the 'true' job");

# Just like the above cases, but combining a background and an exec

$cmd = Lintian::Command::Simple->new();

cmp_ok($cmd->background("true"), '>', 0, 'Running one job is ok');
is($cmd->run("false"), -1, 'Running exec() before wait()ing is not');

is($cmd->wait(), 0, "We wait() for the 'true' job");

# It can happen that a pid-less call to wait() reaps a job started by
# an instance of the object. Make sure this case is handled nicely.

$cmd = Lintian::Command::Simple->new();

$cmd->background("true");

is(wait(), $cmd->pid, 'Another wait() call reaps an OO job');

is($cmd->wait(), -1, "We only know the job is gone, no return status");

# But it was reaped anyway, so make sure it is possible to start
# another job via the same object.

cmp_ok($cmd->background("true"), '>', 0, 'Running a second job is ok after foreign wait()');
is($cmd->wait(), 0, "We wait() for the 'true' job");

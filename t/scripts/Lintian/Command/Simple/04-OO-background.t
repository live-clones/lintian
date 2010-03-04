#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 6;

use Lintian::Command::Simple;

my ($cmd, $pid);

$cmd = Lintian::Command::Simple->new();

$pid = $cmd->fork("true");

cmp_ok($pid, '>', 0, 'Basic fork (true)');
is(waitpid($pid, 0), $pid, "Waiting for pid");
is($?, 0, "Return status is 0");

# Again but using helper function

$cmd = Lintian::Command::Simple->new();
$pid = $cmd->fork("true");

cmp_ok($pid, '>', 0, 'Basic fork (true), take two');
is($cmd->wait(), 0, "Waiting and checking return status");
is(waitpid($pid, 0), -1, "Process was really reaped");

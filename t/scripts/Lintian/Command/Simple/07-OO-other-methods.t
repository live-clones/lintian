#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Command::Simple;

my ($cmd, $pid);

$cmd = Lintian::Command::Simple->new();

$pid = $cmd->fork("true");
is($cmd->pid(), $pid, 'pid() returns PID after fork()');

$cmd->wait();

# Using an object to run exec() should not preserve the old pid.
# However, this test should never fail if we wait()ed for the old process

$cmd->exec("true");
isnt($cmd->pid(), $pid, 'pid() is no longer the old PID after exec()');

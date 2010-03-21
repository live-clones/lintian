#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 10;

use Lintian::Command::Simple;

my ($cmd, $pid);

$cmd = Lintian::Command::Simple->new();

# pid():

is($cmd->pid(), undef, 'pid() returns undef without fork()');

$pid = $cmd->fork("true");
is($cmd->pid(), $pid, 'pid() returns PID after fork()');

$cmd->wait();

is($cmd->pid(), undef, 'pid() returns undef after wait()');

# status():

$cmd = Lintian::Command::Simple->new();

is($cmd->status(), undef, 'status() returns undef without fork()');

$cmd->fork("true");
is($cmd->status(), undef, 'status() returns undef without wait()');

$cmd->wait();

is($cmd->status(), 0, 'status() is 0 after wait()');

$cmd->fork("false");
is($cmd->status(), undef, 'status() returns undef after another fork()');

$cmd->wait();

is($cmd->status(), 1, 'status() is 1 after wait()');

# status() with exec()

$cmd = Lintian::Command::Simple->new();

$cmd->exec("true");
is($cmd->status(), 0, "status() returns 0 for exec(true)");
$cmd->exec("false");
is($cmd->status(), 1, "status() returns 1 for exec(false)");

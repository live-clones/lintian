#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 10;

use Lintian::Command::Simple;

my ($cmd, $pid);

$cmd = Lintian::Command::Simple->new();

# pid():

is($cmd->pid(), undef, 'pid() returns undef without background()');

$pid = $cmd->background("true");
is($cmd->pid(), $pid, 'pid() returns PID after background()');

$cmd->wait();

is($cmd->pid(), undef, 'pid() returns undef after wait()');

# status():

$cmd = Lintian::Command::Simple->new();

is($cmd->status(), undef, 'status() returns undef without background()');

$cmd->background("true");
is($cmd->status(), undef, 'status() returns undef without wait()');

$cmd->wait();

is($cmd->status(), 0, 'status() is 0 after wait()');

$cmd->background("false");
is($cmd->status(), undef, 'status() returns undef after another background()');

$cmd->wait();

is($cmd->status(), 1, 'status() is 1 after wait()');

# status() with run()

$cmd = Lintian::Command::Simple->new();

$cmd->run("true");
is($cmd->status(), 0, "status() returns 0 for run(true)");
$cmd->run("false");
is($cmd->status(), 1, "status() returns 1 for run(false)");

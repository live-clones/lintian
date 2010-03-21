#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Command::Simple;

my ($cmd, $pid);

$cmd = Lintian::Command::Simple->new();

$cmd->background("sleep", 10);

is($cmd->kill(), 1, "One process was killed");
is($cmd->wait(), 0, "One process was reaped");

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

use Lintian::Command::Simple;

my $cmd;

ok(eval { $cmd = Lintian::Command::Simple->new(); }, 'Create');

is($cmd->run("true"), 0, 'Basic run (true)');
is($cmd->run("false"), 1, 'Basic run (false)');

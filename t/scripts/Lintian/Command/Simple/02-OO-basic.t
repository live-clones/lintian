#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

use Lintian::Command::Simple;

my $cmd;

ok(eval { $cmd = Lintian::Command::Simple->new(); }, 'Create');

is($cmd->exec("true"), 0, 'Basic exec (true)');
is($cmd->exec("false"), 1, 'Basic exec (false)');

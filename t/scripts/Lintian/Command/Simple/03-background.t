#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 6;

use Lintian::Command::Simple;

my $pid;

$pid = Lintian::Command::Simple::background("true");
cmp_ok($pid, '>', 0, 'Basic background (true)');

is(waitpid($pid, 0), $pid, "Waiting for pid");
is($?, 0, "Return status is 0");

# Again but using helper function

$pid = Lintian::Command::Simple::background("true");
cmp_ok($pid, '>', 0, 'Basic background (true), take two');

is(Lintian::Command::Simple::wait($pid), 0, "Waiting and checking return status");
is(waitpid($pid, 0), -1, "Process was really reaped");

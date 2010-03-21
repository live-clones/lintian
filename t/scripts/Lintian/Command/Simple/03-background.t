#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 9;

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

# One more time, but without passing a pid to wait()

$pid = Lintian::Command::Simple::background("true");
cmp_ok($pid, '>', 0, 'Basic background (true), take three');

is(Lintian::Command::Simple::wait(), 0, "Waiting and checking \$? of any child");
is(wait(), -1, "Process was really reaped");

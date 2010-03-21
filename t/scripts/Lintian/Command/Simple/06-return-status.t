#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Command::Simple;

my $pid;

$pid = Lintian::Command::Simple::background("false");

is(Lintian::Command::Simple::wait($pid), 1, "Waiting with pid and checking return status");

# One more time, but without passing a pid to wait()

$pid = Lintian::Command::Simple::background("false");

is(Lintian::Command::Simple::wait(), 1, "Waiting without pid and checking return status");

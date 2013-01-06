#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 1;

use Lintian::Command::Simple;

my $pid;

$pid = Lintian::Command::Simple::background("false");

is(Lintian::Command::Simple::wait($pid), 1, "Waiting with pid and checking return status");


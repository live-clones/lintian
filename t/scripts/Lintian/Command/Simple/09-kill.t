#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Command::Simple;

my $pid;

$pid = Lintian::Command::Simple::background("sleep", 10);

is(Lintian::Command::Simple::kill($pid), 1, "One job was killed");

is(Lintian::Command::Simple::wait($pid), 0, "The job was reaped");

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Command::Simple;

my $cmd;
my $c = 4;
my %jobs;

while ($c) {
    $cmd = Lintian::Command::Simple->new();
    $cmd->background("sleep", 10);
    $jobs{$c} = $cmd;
    $c--;
}

is(Lintian::Command::Simple::kill(\%jobs), 4, "4 jobs were killed");

is(Lintian::Command::Simple::wait(\%jobs), undef,
	"kill(hashref) kills and reaps");

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

use Lintian::Command::Simple qw(background);

my $pid = background ('true');
cmp_ok($pid, '>', 0, 'Basic background (true)');

is(waitpid($pid, 0), $pid, 'Waiting for pid');
is($?, 0, 'Return status is 0');


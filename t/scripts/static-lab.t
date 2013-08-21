#!/usr/bin/perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::Simple tests => 4;

$ENV{'LINTIAN_ROOT'} //= '.';

my $lintian_path = "$ENV{LINTIAN_ROOT}/frontend/lintian";
my $labdir = tempdir(CLEANUP => 1);

$lintian_path = $ENV{'LINTIAN_FRONTEND'} if exists($ENV{'LINTIAN_FRONTEND'});

ok(system("$lintian_path --allow-root --lab $labdir --setup-lab") == 0,
    'Create');
ok(system("$lintian_path --allow-root --lab $labdir --setup-lab") == 0,
    'Renew');
ok(system("$lintian_path --allow-root --lab $labdir --remove-lab") == 0,
    'Remove');
ok(system("rmdir $labdir") == 0, 'Rmdir');

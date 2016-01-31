#!/usr/bin/perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::Simple tests => 4;

$ENV{'LINTIAN_TEST_ROOT'} //= '.';

my $dplint = "$ENV{LINTIAN_TEST_ROOT}/frontend/dplint";
my $labdir = tempdir(CLEANUP => 1);

$dplint = $ENV{'LINTIAN_DPLINT_FRONTEND'}
  if exists($ENV{'LINTIAN_DPLINT_FRONTEND'});

ok(system($dplint, 'lab-tool', 'create-lab', $labdir) == 0, 'Create');
ok(system($dplint, 'lab-tool', 'scrub-lab', $labdir) == 0, 'Scrub');
ok(system($dplint, 'lab-tool', 'remove-lab', $labdir) == 0, 'Remove');
ok(system('rmdir', $labdir) == 0, 'Rmdir');

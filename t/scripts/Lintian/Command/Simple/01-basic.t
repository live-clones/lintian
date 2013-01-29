#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok('Lintian::Command::Simple', 'rundir'); }

is(rundir('/bin', './true'), 0, 'Basic run (cd /bin && ./true)');

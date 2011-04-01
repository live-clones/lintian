#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok('Lintian::Command::Simple'); }

is(Lintian::Command::Simple::run('true'), 0, 'Basic run (true)');
is(Lintian::Command::Simple::run('false'), 1, 'Basic run (false)');
is(Lintian::Command::Simple::rundir('/bin', './true'), 0, 'Basic run (cd /bin && ./true)');

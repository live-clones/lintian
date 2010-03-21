#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok('Lintian::Command::Simple'); }

is(Lintian::Command::Simple::run("true"), 0, 'Basic run (true)');
is(Lintian::Command::Simple::run("false"), 1, 'Basic run (false)');

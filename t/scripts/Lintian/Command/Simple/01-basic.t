#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok('Lintian::Command::Simple'); }

is(Lintian::Command::Simple::exec("true"), 0, 'Basic exec (true)');
is(Lintian::Command::Simple::exec("false"), 1, 'Basic exec (false)');

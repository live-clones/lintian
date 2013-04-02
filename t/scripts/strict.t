#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
eval 'use Test::Strict';
plan skip_all => "Test::Strict required to run this test" if $@;

my @DIRS = map { "$ENV{'LINTIAN_ROOT'}/$_" } qw(lib private frontend);
all_perl_files_ok(@DIRS);

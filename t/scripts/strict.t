#!/usr/bin/perl -w

use strict;
use warnings;
use autodie;

use Test::More;
eval 'use Test::Strict';
plan skip_all => 'Test::Strict required to run this test' if $@;

{
    no warnings 'once';
    $Test::Strict::TEST_WARNINGS = 1;
}

$ENV{'LINTIAN_ROOT'} //= '.';

my @DIRS = map { "$ENV{'LINTIAN_ROOT'}/$_" } qw(lib private frontend helpers collection checks doc/examples/checks);
all_perl_files_ok(@DIRS);

# html_reports loads ./config, so we have do chdir before checking it.
chdir("$ENV{'LINTIAN_ROOT'}/reporting");
all_perl_files_ok('.');

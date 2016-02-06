#!/usr/bin/perl -w

use strict;
use warnings;
use autodie;

use
  if $ENV{'LINTIAN_COVERAGE'}, 'Test::More',
  'skip_all' => 'Not needed for coverage of Lintian';

eval 'use Test::Strict';
plan skip_all => 'Test::Strict required to run this test' if $@;

{
    no warnings 'once';
    $Test::Strict::TEST_WARNINGS = 1;
}

$ENV{'LINTIAN_TEST_ROOT'} //= '.';
# Files in commands check for the presence of LINTIAN_INCLUDE_DIRS in
# BEGIN, so make sure it is present for them.
$ENV{'LINTIAN_INCLUDE_DIRS'} = $ENV{'LINTIAN_TEST_ROOT'};

my @DIRS = map { "$ENV{'LINTIAN_TEST_ROOT'}/$_" }
  qw(lib private frontend helpers collection checks commands doc/examples/checks);
all_perl_files_ok(@DIRS);

# html_reports loads ./config, so we have do chdir before checking it.
chdir("$ENV{'LINTIAN_TEST_ROOT'}/reporting");
all_perl_files_ok('.');

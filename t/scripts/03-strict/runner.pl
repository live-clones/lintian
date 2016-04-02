#!/usr/bin/perl -w

use strict;
use warnings;
use autodie;

use Test::Lintian;
use Test::More;
if ($ENV{'LINTIAN_COVERAGE'}) {
    plan 'skip_all' => 'Not needed for coverage of Lintian';
}

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

if ($0 =~ m{^(?:.*/)?reporting\.t$}) {
    # html_reports loads ./config, so we have do chdir before checking it.
    chdir("$ENV{'LINTIAN_TEST_ROOT'}/reporting");
    all_perl_files_ok('.');
} else {
    my @test_paths = program_name_to_perl_paths($0);
    all_perl_files_ok(@test_paths);
}

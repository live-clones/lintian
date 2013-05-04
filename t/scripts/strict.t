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

my @DIRS = map { "$ENV{'LINTIAN_ROOT'}/$_" } qw(lib private frontend collection);
my @CHECKS = glob("$ENV{'LINTIAN_ROOT'}/checks/*[!.]*[!c]");
all_perl_files_ok(@DIRS);

for my $check (@CHECKS) {
    # syntax_ok does not like our checks.  However, those are covered
    # by check-load.t, so it is not a huge problem.
    strict_ok($check);
    warnings_ok($check);
}

# html_reports loads ./config, so we have do chdir before checking it.
chdir("$ENV{'LINTIAN_ROOT'}/reporting");
all_perl_files_ok('.');

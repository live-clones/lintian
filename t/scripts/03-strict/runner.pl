#!/usr/bin/perl

use strict;
use warnings;

use Const::Fast;
use Test::More;

use Test::Lintian;

const my $DOT => q{.};

if ($ENV{'LINTIAN_COVERAGE'}) {
    plan 'skip_all' => 'Not needed for coverage of Lintian';
}

eval 'use Test::Strict';
plan skip_all => 'Test::Strict required to run this test' if $@;

{
    no warnings 'once';
    $Test::Strict::TEST_WARNINGS = 1;
}

$ENV{'LINTIAN_BASE'} //= $DOT;
# Files in commands check for the presence of LINTIAN_INCLUDE_DIRS in
# BEGIN, so make sure it is present for them.
$ENV{'LINTIAN_INCLUDE_DIRS'} = $ENV{'LINTIAN_BASE'};

if ($0 =~ m{^(?:.*/)?reporting\.t$}) {
    # html_reports loads ./config, so we have do chdir before checking it.
    my $folder = "$ENV{LINTIAN_BASE}/reporting";
    chdir($folder)
      or die "Cannot change directory $folder";

    all_perl_files_ok($DOT);

} else {
    my @test_paths = program_name_to_perl_paths($0);
    all_perl_files_ok(@test_paths);
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

use strict;
use warnings;

use Const::Fast;
use Test::More;
use Test::Lintian;

plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};
eval 'use Test::MinimumVersion';
plan skip_all => 'Test::MinimumVersion required to run this test' if $@;

const my $DOT => q{.};

# squeeze => 5.10.1, Wheezy => 5.14.2, stretch => 5.24.1
our $REQUIRED = 'v5.24.1';

my @test_paths = program_name_to_perl_paths($0);
$ENV{'LINTIAN_BASE'} //= $DOT;

all_minimum_version_ok($REQUIRED, { paths => \@test_paths, no_plan => 1});

done_testing();

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

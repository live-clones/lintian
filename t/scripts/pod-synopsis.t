#!/usr/bin/perl

use strict;
use warnings;

use Const::Fast;
use Test::More;

use Test::Lintian;

const my $DOT => q{.};

load_profile_for_test;

plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};
eval 'use Test::Pod';
plan skip_all => 'Test::Pod required for testing' if $@;
eval 'use Test::Synopsis';
plan skip_all => 'Test::Synopsis required for testing' if $@;

$ENV{'LINTIAN_BASE'} //= $DOT;

my @pod_files = all_pod_files("$ENV{'LINTIAN_BASE'}/lib");
plan tests => scalar(@pod_files);
synopsis_ok(@pod_files);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

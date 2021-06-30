#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Test::Lintian;

plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};

plan skip_all => 'Test::Pod::Coverage 1.08 required for this test'
  unless eval 'use Test::Pod::Coverage 1.08; 1';

load_profile_for_test;

# exempt checks and screens
my @modules = grep { !/^Lintian::(?:Check|Screen)::/ } all_modules('lib');

plan tests => scalar @modules;

pod_coverage_ok($_, { coverage_class => 'Pod::Coverage::TrustPod' })
  for @modules;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

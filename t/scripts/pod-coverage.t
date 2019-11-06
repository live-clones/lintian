#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};

plan skip_all => 'Test::Pod::Coverage 1.08 required for this test'
  unless eval 'use Test::Pod::Coverage 1.08; 1';

all_pod_coverage_ok({ coverage_class => 'Pod::Coverage::TrustPod' });

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

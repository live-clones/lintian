#!/usr/bin/perl
#
# Test POD formatting.  Taken essentially verbatim from the examples in the
# Test::Pod documentation.

use strict;
use warnings;
use Test::More;
eval 'use Test::Pod 1.00';
plan skip_all => 'Test::Pod 1.00 required for testing POD' if $@;

my $dir = $ENV{'LINTIAN_TEST_ROOT'} // '.';

my @POD_FILES = all_pod_files("$dir/lib", "$dir/doc/tutorial");
push(@POD_FILES, map { "$dir/man/$_" } 'lintian-info.pod', 'lintian.pod.in');

all_pod_files_ok(@POD_FILES);


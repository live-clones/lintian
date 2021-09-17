#!/usr/bin/perl
#
# Test POD formatting.  Taken essentially verbatim from the examples in the
# Test::Pod documentation.

use strict;
use warnings;

use Const::Fast;
use Test::More;

plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};

eval 'use Test::Pod 1.00';

const my $DOT => q{.};

my $dir = $ENV{'LINTIAN_BASE'} // $DOT;

my @POD_SOURCES = grep { -e } (
    "$dir/lib",
    "$dir/doc/tutorial",
    "$dir/man/lintian.pod",
    "$dir/man/lintian-annotate-hints.pod",
    "$dir/man/lintian-explain-tags.pod",
);

my @POD_FILES = all_pod_files(@POD_SOURCES);

all_pod_files_ok(@POD_FILES);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

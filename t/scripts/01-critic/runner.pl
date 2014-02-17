#!/usr/bin/perl

# Simple critic test runner that guesses it task from $0.
# NB: If you change anything in this script, consider if
# others.t need an update as well.

use strict;
use warnings;

use
  if $ENV{'LINTIAN_COVERAGE'}, 'Test::More',
  'skip_all' => 'Not needed for coverage of Lintian';

use Cwd qw(realpath);
use File::Basename qw(basename dirname);

my ($dir, $basename);

BEGIN {
    my $me = realpath($0) // die("realpath($0): $!");

    # We need the basename before resolving the path (because
    # afterwards it is "runner.pl" and we want it to be e.g.
    # "checks.t" or "collections.t").
    $basename = basename($0, '.t');
    $dir = dirname($me);
}
use lib $dir;
use critic qw(run_critic);

run_critic($basename);

exit(0);


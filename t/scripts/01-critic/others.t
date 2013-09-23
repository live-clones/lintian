#!/usr/bin/perl

# Copy of runner.pl that works on a hard-coded list of paths.  NB: If
# you change anything here, consider if runner.pl needs an update as
# well.

use strict;
use warnings;

use Cwd qw(realpath);
use File::Basename qw(dirname);

my @FILES_OR_DIRS_TO_PROCESS = qw(
  t/scripts t/helpers doc/examples/checks t/runtests
);

my ($dir);

BEGIN {
    my $me = realpath($0) // die("realpath($0): $!");
    $dir = dirname($me);
}
use lib $dir;
use critic qw(run_critic);

run_critic(@FILES_OR_DIRS_TO_PROCESS);

exit(0);


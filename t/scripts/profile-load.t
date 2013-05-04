#!/usr/bin/perl

# Test that all profiles are loadable...

use strict;
use warnings;

use Test::More;

BEGIN {
    $ENV{'LINTIAN_ROOT'} //= '.';
}

use lib "$ENV{'LINTIAN_ROOT'}/lib";

use Test::Lintian;

# We could use a plan, but then we had to update every time we added
# or removed a profile...
test_load_profiles ($ENV{'LINTIAN_ROOT'}, $ENV{'LINTIAN_ROOT'});

done_testing;


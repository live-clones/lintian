#!/usr/bin/perl

# Test that all profiles are loadable...

use strict;
use warnings;

use Const::Fast;
use Test::More;

use Test::Lintian;

const my $DOT => q{.};

$ENV{'LINTIAN_BASE'} //= $DOT;

# We could use a plan, but then we had to update every time we added
# or removed a profile...
test_load_profiles($ENV{'LINTIAN_BASE'}, $ENV{'LINTIAN_BASE'});

done_testing;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok('Lintian::Relation'); }

my $relation = Lintian::Relation->new('pkgA, altA | altB');

ok($relation->implies('pkgA'),   'Implies');
ok(!$relation->implies('altA'),  'Implies alt');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

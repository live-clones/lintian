#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok('Lintian::Relation'); }

my $relation = Lintian::Relation->new('pkgA, altA | altB');

ok($relation->implies('pkgA'),   'Implies');
ok(!$relation->implies('altA'),  'Implies alt');


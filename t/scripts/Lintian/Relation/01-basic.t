#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

use Lintian::Relation;

my $relation = Lintian::Relation->new->load('pkgA, altA | altB');

ok($relation->satisfies('pkgA'),   'Satisfies');
ok(!$relation->satisfies('altA'),  'Satisfies alt');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

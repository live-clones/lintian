#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

use Lintian::Relation;

my $relation_a
  = Lintian::Relation->new->load_norestriction(
    'pkgA, pkgB, pkgC, pkgA | pkgD');

my $relation_b
  = Lintian::Relation->new->load_norestriction(
    'pkgA, pkgB, pkgC, pkgD | pkgE');

is_deeply(
    $relation_a->redundancies,
    (['pkgA', 'pkgA | pkgD']),
    'Find redundancies'
);
is($relation_b->redundancies, 0, 'No redundancies');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

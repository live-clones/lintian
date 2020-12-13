#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Relation;

my $relationA
  = Lintian::Relation->new->load_noarch('pkgA, pkgB, pkgC, pkgA | pkgD');

my $relationB
  = Lintian::Relation->new->load_noarch('pkgA, pkgB, pkgC, pkgD | pkgE');

is_deeply($relationA->duplicates, (['pkgA', 'pkgA | pkgD']), 'Duplicates');
is($relationB->duplicates, 0, 'No duplicates');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

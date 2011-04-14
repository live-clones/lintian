#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Relation;

my $relationA = Lintian::Relation->new_noarch('pkgA, pkgB, pkgC, pkgA | pkgD');
my $relationB = Lintian::Relation->new_noarch('pkgA, pkgB, pkgC, pkgD | pkgE');

is_deeply($relationA->duplicates, (['pkgA', 'pkgA | pkgD']), 'Duplicates');
is($relationB->duplicates, 0, 'No duplicates');


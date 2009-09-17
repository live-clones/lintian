#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 5;

use Lintian::DepMap;

my $map = Lintian::DepMap->new();

$map->add('A');
is($map->pending(), 1, 'A added, one pending');

$map->add('B');
is($map->pending(), 2, 'B added, two pending');

$map->select('A');
is($map->pending(), 2, 'A selected, two pending');

$map->satisfy('B');
is($map->pending(), 1, 'B satisfied, one pending');

$map->satisfy('A');
is($map->pending(), 0, 'A satisfied, zero pending');

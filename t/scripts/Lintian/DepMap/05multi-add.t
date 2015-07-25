#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 4;

use Lintian::DepMap;

my $map = Lintian::DepMap->new();

$map->add('A');
$map->add('B');
$map->add('C');
$map->add('D');
$map->add('D', 'A');
$map->add('D', 'B', 'C');

is_deeply(
    [sort($map->selectable)],
    ['A', 'B', 'C'],
    'D has dependencies, not selectable'
);

$map->satisfy('A');
is_deeply(
    [sort($map->selectable)],
    ['B', 'C'],
    'A satisfied, B and C selectable'
);

$map->satisfy('B');
is_deeply([$map->selectable()], ['C'], 'B satisfied, C selectable');

$map->satisfy('C');
is_deeply([$map->selectable()], ['D'], 'C satisfied, D now selectable');

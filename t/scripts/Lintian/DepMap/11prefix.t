#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 2;

use Lintian::DepMap;

my $map = Lintian::DepMap->new;

$map->add('pA');
$map->add('pB', 'pA');
ok(eval {$map->addp('foo', 'p', 'A')}, 'Add foo depending on "p"+"A"');

$map->satisfy('pA');

ok($map->selectable('foo'), 'foo is selectable');

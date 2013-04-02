#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 5;

use Lintian::DepMap;

my $map = Lintian::DepMap->new();

$map->add('A', 'B');
$map->add('B', 'A');

is(join(', ', sort($map->circular())), 'A, B', 'A and B cause a circular dependency');

$map->add('C');

is(join(', ', sort($map->circular())), 'A, B', 'A and B cause a circular dependency (2nd)');

$map = Lintian::DepMap->new();
$map->add('A', 'B');
$map->add('B', 'C');
$map->add('C', 'A');

is(join(', ', sort($map->circular('deep'))), 'A, B, C', 'A, B and C cause a deep circular dependency');

TODO: {
    local $TODO = 'When C is unlinked, A and B are not reconsidered to be added to {"map"}';

    # We break the circular dependency:
    $map->unlink('C');
    is(join(', ', $map->circular('deep')), '', 'Deep circular dependency is now broken (w/o C)');

    $map->add('C');
    is(join(', ', $map->circular('deep')), '', 'C re-added, circular dependency still broken');
}

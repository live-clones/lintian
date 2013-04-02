#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 15;

use Lintian::DepMap;

my $map;

$map = Lintian::DepMap->new();

$map->add('A');
ok(eval {$map->unlink('A')}, 'Unlink A');
is_deeply([$map->selectable()], [], 'A unlinked, not selectable');
is($map->pending(), 0, 'A unlinked, nothing pending');

$map->add('B', 'A');
is_deeply([$map->selectable()], [], 'A unlinked, B added but not selectable');
is($map->pending(), 0, 'A unlinked, B added but not pending');

$map->add('A');
is_deeply([$map->selectable()], ['A'], 'A re-added, selectable');
is($map->pending(), 1, 'A re-added, pending');

$map->satisfy('A');
is_deeply([$map->selectable()], ['B'], 'A satisfied, B is now selectable');

# re-add A for the following tests
$map->add('A');

ok(eval {$map->unlink('B')}, 'Unlink B');
is_deeply([$map->selectable()], ['A'], 'B unlinked, A selectable');
is($map->pending(), 1, 'B unlinked, pending');

$map->satisfy('A');
is_deeply([$map->selectable()], [], 'A satisfied, nothing selectable');
is($map->pending(), 0, 'A satisfied, nothing pending');

$map->add('A', 'B');
$map->add('B');

$map->unlink('B', 'soft');
ok(!$map->satisfy('A'), "A can't be satisfied because it depends on the soft-unlinked B");

TODO: {
    local $TODO = 'When re-adding B there are still references to the old B, and old $B != new $B';
    $map->add('B');
    $map->satisfy('B');
    ok(eval {$map->satisfy('A')}, 'B re-added, A can be satisfied');
}

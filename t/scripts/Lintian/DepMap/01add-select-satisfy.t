#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 24;

BEGIN { use_ok('Lintian::DepMap'); }

my $map;

ok(eval { $map = Lintian::DepMap->new; }, 'Create');

is_deeply([$map->selectable], [], 'Empty, nothing is selectable');
is_deeply([$map->selected], [], 'Empty, nothing has been selected');
ok($map->pending == 0, 'Empty, nothing is pending');
is_deeply([$map->known], [], 'Empty, nothing is known');
is_deeply([$map->missing], [], 'Empty, nothing is missing');

ok(eval { $map->add('A'); }, 'Add A');
is_deeply([$map->selectable], ['A'], 'A is selectable');
ok($map->pending == 1, 'A is pending');
is_deeply([$map->known], ['A'], 'A added, it is known');
is_deeply([$map->missing], [], 'A added, it is not missing');

ok(eval { $map->select('A'); }, 'Select A');
is_deeply([$map->selectable], [], 'A selected, nothing is selectable');
ok($map->selected('A'), 'A selected, A has been selected');
ok($map->pending == 1, 'A selected, A is still pending');
is_deeply([$map->known], ['A'], 'A selected, it is known');
is_deeply([$map->missing], [], 'A selected, nothing is missing');

ok(eval { $map->satisfy('A'); }, 'Satisfy A');
is_deeply([$map->selectable], [], 'A satisfied, nothing is selectable');
is_deeply([$map->selected], [], 'A satisfied, nothing is selected');
ok($map->pending == 0, 'A satisfied, nothing is pending');
is_deeply([$map->known], ['A'], 'A satisfied, it is known');
is_deeply([$map->missing], [], 'A satisfied, nothing is missing');

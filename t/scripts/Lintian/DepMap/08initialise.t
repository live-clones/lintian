#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 7;

use Lintian::DepMap;

my $obj = Lintian::DepMap->new();

ok($obj->initialise(), 'Map can be initialised');

$obj->add('A');
$obj->select('A');
$obj->initialise();
is(join(', ', $obj->selectable),
    'A','A is selectable once again after being selected');

$obj->satisfy('A');
$obj->initialise();
is(join(', ', $obj->selectable),
    'A','A is selectable once again after being satisfied');

$obj->add('B');
$obj->satisfy('B');
$obj->initialise();
is(join(', ', sort($obj->selectable)),
    'A, B','A and B are selectable once again after being satisfied');

$obj->add('B', 'A');
$obj->satisfy('A');
$obj->initialise();
is(join(', ', $obj->parents('B')), 'A','A is parent of B');

$obj->add('Z', 'X');
$obj->initialise();
is(join(', ', $obj->missing()), 'X', 'X is unknown');
is(join(', ', sort($obj->known())), 'A, B, Z', 'X is not known');

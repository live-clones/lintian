#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 4;

use Lintian::DepMap;

my $obj = Lintian::DepMap->new();

ok($obj->add('A', 'B'), 'Nodes can be added in any order');

eval {$obj->satisfy('Z')};
isnt($@, '', 'Nodes that were not added can not be satisfied');

eval {$obj->satisfy('B')};
isnt($@, '', 'Nodes that were not added and are missing() can not be satisfied');

ok(!$obj->satisfy('A'), 'Nodes can not be satisfied if they still have dependencies');

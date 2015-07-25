#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 4;

use Lintian::DepMap;

my $obj = Lintian::DepMap->new();

$obj->add('A');
ok(!$obj->done('A'), 'A is not done yet');
ok(!$obj->done('B'), 'B is not done yet');

$obj->select('A');
ok(!$obj->done('A'), 'A is still not done');

$obj->satisfy('A');
ok($obj->done('A'), 'A is finally done');


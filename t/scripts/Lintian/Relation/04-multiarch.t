#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Relation;

my $relation = Lintian::Relation->new('pkgA:i386');

ok($relation->implies('pkgA:i386'),   'Same arch implies');
ok($relation->implies('pkgA'),        'Archless implies');

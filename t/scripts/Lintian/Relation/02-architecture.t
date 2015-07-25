#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Relation;

my $relation = Lintian::Relation->new_noarch('pkgA [i386], pkgB [amd64]');

ok($relation->implies('pkgA'),  'Implies arch alt [i386]');
ok($relation->implies('pkgB'),  'Implies arch alt [amd64]');

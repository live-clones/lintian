#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

use Lintian::Relation;

my $relation = Lintian::Relation->new_norestriction(
    'pkgA (<= 1.0) <stage1 nocheck> <nobiarch>, pkgB (<< 1.0) <!nodoc>');

ok($relation->implies('pkgA'),
    'Implies restriction <stage1 nocheck> <nobiarch>');
ok($relation->implies('pkgB'),  'Implies restriction <!nodoc>');

my $rel = Lintian::Relation->new('pkgC   <foo bar> <baz>');

is($rel->unparse, 'pkgC <foo bar> <baz>', 'Unparse pkgC');

#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

use Lintian::Relation;

my $relation = Lintian::Relation->new->load_norestriction(
    'pkgA (<= 1.0) <stage1 nocheck> <nobiarch>, pkgB (<< 1.0) <!nodoc>');

ok($relation->satisfies('pkgA'),
    'Satisfies restrictions <stage1 nocheck> <nobiarch>');
ok($relation->satisfies('pkgB'),  'Satisfies restriction <!nodoc>');

my $rel = Lintian::Relation->new->load('pkgC   <foo bar> <baz>');

is($rel->to_string, 'pkgC <foo bar> <baz>', 'Reconstitute pkgC');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

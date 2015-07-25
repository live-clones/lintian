#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

use Lintian::Relation;

my $orig = 'pkgA:any, pkgB, pkgC:i386';
my $relation = Lintian::Relation->new($orig);

ok($relation->implies('pkgA:any'),   'identity implies [pkgA]');

ok($relation->implies('pkgB'),       'identity implies [pkgB]');

ok(!$relation->implies('pkgC'),      'archless implies [pkgC]');
ok($relation->implies('pkgC:i386'),  'identity implies [pkgC]');

ok($relation->implies('pkgB:any'),   'arch any implies [pkgB]');

TODO: {
    local $TODO = ':X => :Y cases are not implemented (in general)';

    ok($relation->implies('pkgA'),       'archless implies [pkgA]');

    ok($relation->implies('pkgC:any'),   'arch any implies [pkgC]');
}

is($relation->unparse, $orig,          'unparse eq original');

my @dups1 =  Lintian::Relation->new('pkgD, pkgD:any')->duplicates;
my @dups2 =  Lintian::Relation->new('pkgD:i386, pkgD:any')->duplicates;
my @dups3 =  Lintian::Relation->new('pkgD:i386, pkgD')->duplicates;
my @dups4
  =  Lintian::Relation->new('pkgD:i386, pkgD:i386 (>= 1.0)')->duplicates;

is_deeply(\@dups1,[['pkgD', 'pkgD:any']],'pkgD and pkgD:any are dups');

is_deeply(\@dups3, [],'pkgD:i386 and pkgD are not dups');
is_deeply(
    \@dups4,
    [['pkgD:i386', 'pkgD:i386 (>= 1.0)']],
    'Can detect pkgD:i386 dups'
);

TODO: {
    local $TODO = ':X => :Y cases are not implemented (in general)';

    is_deeply(
        \@dups2,
        [['pkgD:i386', 'pkgD:any']],
        'pkgD:i386 and pkgD:any are dups'
    );
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

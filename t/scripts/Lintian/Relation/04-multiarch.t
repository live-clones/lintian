#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

use Lintian::Relation;

my $orig = 'pkgA:any, pkgB, pkgC:i386';
my $relation = Lintian::Relation->new->load($orig);

ok($relation->implies('pkgA:any'),   'pkgA:any implies pkgA:any');

ok($relation->implies('pkgB'),       'pkgB implies pkgB');

ok(!$relation->implies('pkgC'),      'pkgC:i386 does not imply pkgC');
ok($relation->implies('pkgC:i386'),  'pkgC:i386 implies pkgC:i386');

ok(!$relation->implies('pkgB:any'),  'pkgB does not imply pkgB:any');

ok($relation->implies('pkgA'),       'pkgA:any implies pkgA');

ok(!$relation->implies('pkgC:any'),  'pkgC:i386 does not imply pkgC:any');

is($relation->to_string, $orig,      'reconstituted eq original');

my @dups1 = Lintian::Relation->new->load('pkgD, pkgD:any')->duplicates;
is_deeply(\@dups1,[['pkgD', 'pkgD:any']],'pkgD and pkgD:any are dups');

TODO: {
    local $TODO = ':X => :Y cases are not implemented (in general)';

    my @dups2= Lintian::Relation->new->load('pkgD:i386, pkgD:any')->duplicates;
    is_deeply(
        \@dups2,
        [['pkgD:i386', 'pkgD:any']],
        'pkgD:i386 and pkgD:any are dups'
    );
}

my @dups3 = Lintian::Relation->new->load('pkgD:i386, pkgD')->duplicates;
is_deeply(\@dups3, [],'pkgD:i386 and pkgD are not dups');

my @dups4
  = Lintian::Relation->new->load('pkgD:i386, pkgD:i386 (>= 1.0)')->duplicates;
is_deeply(
    \@dups4,
    [['pkgD:i386', 'pkgD:i386 (>= 1.0)']],
    'Can detect pkgD:i386 dups'
);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

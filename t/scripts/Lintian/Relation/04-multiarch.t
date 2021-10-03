#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;

use Lintian::Relation;

my $orig = 'pkgA:any, pkgB, pkgC:i386';
my $relation = Lintian::Relation->new->load($orig);

ok($relation->implies('pkgA:any'),   'pkgA:any implies pkgA:any');

ok($relation->implies('pkgB'),       'pkgB implies pkgB');
# pkgB implies pkgB:i386 if and only if the dependency is seen in an i386
# package, but looking at the dependencies out of context like this, we
# can't tell whether that's the case.
ok(!$relation->implies('pkgB:i386'), 'pkgB does not imply pkgB:i386');

ok(!$relation->implies('pkgC'),      'pkgC:i386 does not imply pkgC');
ok($relation->implies('pkgC:i386'),  'pkgC:i386 implies pkgC:i386');

# If we have pkgB:<arch> for some specific architecture, then it's certainly
# true that we have pkgB for at least one architecture
ok($relation->implies('pkgB:any'),   'pkgB implies pkgB:any');

# pkgA:any does not imply pkgA, because if pkgA is Multi-Arch: allowed,
# depending on pkgA is shorthand for pkgA:<arch> for some specific
# architecture, whereas pkgA:any could be satisfied by an architecture
# other than <arch>
ok(!$relation->implies('pkgA'),      'pkgA:any does not imply pkgA');

# If we have pkgC:i386, then it's certainly true that we have pkgC for at
# least one architecture
ok($relation->implies('pkgC:any'),   'pkgC:i386 implies pkgC:any');

is($relation->to_string, $orig,      'reconstituted eq original');

# { pkgD, pkgD:any } is equivalent to { pkgD }
my @dups1 = Lintian::Relation->new->load('pkgD, pkgD:any')->duplicates;
is_deeply(\@dups1,[['pkgD', 'pkgD:any']],'pkgD and pkgD:any are dups');

# { pkgD:i386, pkgD:any } is equivalent to { pkgD:i386 }
my @dups2= Lintian::Relation->new->load('pkgD:i386, pkgD:any')->duplicates;
is_deeply(
    \@dups2,
    [['pkgD:i386', 'pkgD:any']],
    'pkgD:i386 and pkgD:any are dups'
);

# pkgD implies pkgD:i386 if and only if the dependency is seen in an i386
# package, but looking at the dependencies out of context like this, we
# can't tell whether that's the case.
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

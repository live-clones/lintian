#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;

use Lintian::Relation;

my $orig = 'pkgA:any, pkgB, pkgC:i386';
my $relation = Lintian::Relation->new->load($orig);

my @implications = (
    { other => 'pkgA:any', implies => 1, desc => 'pkgA:any implies pkgA:any' },

    { other => 'pkgB', implies => 1, desc => 'pkgB implies pkgB' },

    # pkgB implies pkgB:i386 if and only if the dependency is seen in an i386
    # package, but looking at the dependencies out of context like this, we
    # can't tell whether that's the case.
    { other => 'pkgB:i386', implies => 0, desc => 'pkgB does not imply pkgB:i386' },

    { other => 'pkgC', implies => 0, desc => 'pkgC:i386 does not imply pkgC' },
    { other => 'pkgC:i386', implies => 1, desc => 'pkgC:i386 implies itself' },

    # If we have pkgB:<arch> for some specific architecture, then it's
    # certainly true that we have pkgB for at least one architecture
    { other => 'pkgB:any', implies => 1, desc => 'pkgB implies pkgB:any' },

    # pkgA:any does not imply pkgA, because if pkgA is Multi-Arch: allowed,
    # depending on pkgA is shorthand for pkgA:<arch> for some specific
    # architecture, whereas pkgA:any could be satisfied by an architecture
    # other than <arch>
    { other => 'pkgA', implies => 0, desc => 'pkgA:any does not imply pkgA' },

    # If we have pkgC:i386, then it's certainly true that we have pkgC for at
    # least one architecture
    { other => 'pkgC:any', implies => 1, desc => 'pkgC:i386 implies pkgC:any' },
);

foreach my $impl (@implications) {
    if ($impl->{implies}) {
        ok($relation->implies($impl->{other}), $impl->{desc});
    } else {
        ok(!$relation->implies($impl->{other}), $impl->{desc});
    }
}

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

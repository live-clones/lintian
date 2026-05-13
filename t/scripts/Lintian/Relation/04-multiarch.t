#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

use Lintian::Relation;

my $orig = 'pkgA:any, pkgB, pkgC:i386';
my $relation = Lintian::Relation->new->load($orig);

my @satisfies_tests = (
    {
        other => 'pkgA',
        satisfies => 0,
        desc => 'pkgA:any does not satisfy pkgA',
    },
    {
        other => 'pkgA:any',
        satisfies => 1,
        desc => 'pkgA:any satisfies pkgA:any',
    },
    {
        other => 'pkgB',
        satisfies => 1,
        desc => 'pkgB satisfies pkgB',
    },
    {
        other => 'pkgB:any',
        satisfies => 1,
        desc => 'pkgB satisfies pkgB:any',
    },
    {
        other => 'pkgC',
        satisfies => 0,
        desc => 'pkgC:i386 does not satisfy pkgC',
    },
    {
        other => 'pkgC:any',
        satisfies => 0,
        desc => 'pkgC:i386 does not satisfy pkgC:any',
    },
    {
        other => 'pkgC:i386',
        satisfies => 1,
        desc => 'pkgC:i386 satisfies pkgC:i386',
    },
);

foreach my $t (@satisfies_tests) {
    if ($t->{satisfies}) {
        ok($relation->satisfies($t->{other}), $t->{desc});
    } else {
        ok(!$relation->satisfies($t->{other}), $t->{desc});
    }
}

is($relation->to_string, $orig,      'reconstituted eq original');

my @redundancies1
  = Lintian::Relation->new->load('pkgD, pkgD:any')->redundancies;
is_deeply(
    \@redundancies1,
    [['pkgD', 'pkgD:any']],
    'pkgD and pkgD:any are redundant'
);

TODO: {
    local $TODO = ':X => :Y cases are not implemented (in general)';

    my @redundancies2
      = Lintian::Relation->new->load('pkgD:i386, pkgD:any')->redundancies;
    is_deeply(
        \@redundancies2,
        [['pkgD:i386', 'pkgD:any']],
        'pkgD:i386 and pkgD:any are redundant'
    );
}

my @redundancies3
  = Lintian::Relation->new->load('pkgD:i386, pkgD')->redundancies;
is_deeply(\@redundancies3, [],'pkgD:i386 and pkgD are not redundant');

my @redundancies4
  = Lintian::Relation->new->load('pkgD:i386, pkgD:i386 (>= 1.0)')
  ->redundancies;
is_deeply(
    \@redundancies4,
    [['pkgD:i386', 'pkgD:i386 (>= 1.0)']],
    'Can detect pkgD:i386 redundancies'
);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

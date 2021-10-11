#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

use Lintian::Relation;

my $orig = 'pkgA:any, pkgB, pkgC:i386';
my $relation = Lintian::Relation->new->load($orig);

ok($relation->satisfies('pkgA:any'),   'pkgA:any satisfies pkgA:any');

ok($relation->satisfies('pkgB'),       'pkgB satisfies pkgB');

ok(!$relation->satisfies('pkgC'),      'pkgC:i386 does not satisfy pkgC');
ok($relation->satisfies('pkgC:i386'),  'pkgC:i386 satisfies pkgC:i386');

ok(!$relation->satisfies('pkgB:any'),  'pkgB does not satisfy pkgB:any');

ok($relation->satisfies('pkgA'),       'pkgA:any satisfies pkgA');

ok(!$relation->satisfies('pkgC:any'),  'pkgC:i386 does not satisfy pkgC:any');

is($relation->to_string, $orig,      'reconstituted eq original');

my @duplicates1 = Lintian::Relation->new->load('pkgD, pkgD:any')->duplicates;
is_deeply(
    \@duplicates1,
    [['pkgD', 'pkgD:any']],
    'pkgD and pkgD:any are duplicates'
);

TODO: {
    local $TODO = ':X => :Y cases are not implemented (in general)';

    my @duplicates2
      = Lintian::Relation->new->load('pkgD:i386, pkgD:any')->duplicates;
    is_deeply(
        \@duplicates2,
        [['pkgD:i386', 'pkgD:any']],
        'pkgD:i386 and pkgD:any are duplicates'
    );
}

my @duplicates3 = Lintian::Relation->new->load('pkgD:i386, pkgD')->duplicates;
is_deeply(\@duplicates3, [],'pkgD:i386 and pkgD are not duplicates');

my @duplicates4
  = Lintian::Relation->new->load('pkgD:i386, pkgD:i386 (>= 1.0)')->duplicates;
is_deeply(
    \@duplicates4,
    [['pkgD:i386', 'pkgD:i386 (>= 1.0)']],
    'Can detect pkgD:i386 duplicates'
);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

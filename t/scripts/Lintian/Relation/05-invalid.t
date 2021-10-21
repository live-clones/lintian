#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Lintian::Relation;

test_relation(
    'pkg%any (>= 1.0)  ,  pkgB   |  _gf  ,  pkgC(>=2.0)',
    'satisfied' => [
        'pkgB | _gf', # partly unparsable, but identity holds
        'pkgC (>= 1.0)', # regular entry
    ],
    'not-satisfied' => [
        'pkg',     # unparsable
        'pkg%any', # unparsable
        'pkgB',    # OR relation with unparsable entry
        '_gf',     # OR relation
    ],
    'unparsable' => ['_gf', 'pkg%any (>= 1.0)'],
    'reconstituted' => 'pkg%any (>= 1.0), pkgB | _gf, pkgC (>= 2.0)'
);

done_testing;

sub test_relation {
    my ($text, %tests) = @_;

    my $relation_under_test = Lintian::Relation->new->load($text);

    my $tests = 0;
    if (my $reconstituted = $tests{'reconstituted'}) {
        is($relation_under_test->to_string,
            $reconstituted, "Reconstitute $text");
        $tests++;
    }

    for my $other_relation (@{$tests{'satisfied'} // [] }) {
        ok($relation_under_test->satisfies($other_relation),
            "'$text' satisfies '$other_relation'");
        $tests++;
    }

    for my $other_relation (@{$tests{'not-satisfied'} // [] }) {
        ok(
            !$relation_under_test->satisfies($other_relation),
            "'$text' does NOT satisfy '$other_relation'"
        );
        $tests++;
    }

    if (my $unparsable = $tests{'unparsable'}) {
        my @actual = $relation_under_test->unparsable_predicates;
        is_deeply(\@actual, $unparsable, "Unparsable entries for '$text'");
    }

    cmp_ok($tests, '>=', 1, "Ran at least one test on '$text'");
    return;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

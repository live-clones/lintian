#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Lintian::Relation;

my @TESTS = (
    # A, B, A->I(B), A->I_I(B), B->I(A), B->I_I(A), line
    # - with "I" being "satisfies" and "I_I" being "satisfies_inverse".
    ['foo (= 1.0)', 'foo (= 2.0)', 0, 1, 0, 1, __LINE__],
    ['foo (>= 1.0)', 'foo (= 2.0)', 0, 0, 1, 0, __LINE__],
    ['foo (>= 2.0)', 'foo (>= 1.0)', 1, 0, 0, 0, __LINE__],
    ['foo (>> 1.0)', 'foo (>= 1.0)', 1, 0, 0, 0, __LINE__],
    ['foo (>> 2.0)', 'foo (>> 1.0)', 1, 0, 0, 0, __LINE__],
    ['foo (<= 1.0)', 'foo (<= 2.0)', 1, 0, 0, 0, __LINE__],
    ['foo (<< 1.0)', 'foo (<= 1.0)', 1, 0, 0, 0, __LINE__],
    ['foo (<< 1.0)', 'foo (<< 2.0)', 1, 0, 0, 0, __LINE__],
);

plan tests => scalar(@TESTS) * 4;

for my $test (@TESTS) {
    my ($a_raw, $b_raw, $a_i_b, $a_ii_b, $b_i_a, $b_ii_a, $lno) = @{$test};

    my $relation_a = Lintian::Relation->new->load($a_raw);
    my $relation_b = Lintian::Relation->new->load($b_raw);

    is($relation_a->satisfies($relation_b),
        $a_i_b, "$a_raw satisfies $b_raw (case 1, line $lno)");
    is($relation_a->satisfies_inverse($relation_b),
        $a_ii_b,"$test->[0] satisfies inverse $test->[1] (case 2, line $lno)");

    is($relation_b->satisfies($relation_a),
        $b_i_a,"$b_raw satisfies $a_raw (case 3, line $test->[6])");
    is($relation_b->satisfies_inverse($relation_a),
        $b_ii_a, "$b_raw satisfies inverse $a_raw (case 4, line $lno)");
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

use strict;
use warnings;
use Lintian::Relation;
use Test::More;

my @TESTS = (
    # A, B, A->I(B), A->I_I(B), B->I(A), B->I_I(A), line
    # - with "I" being "implies" and "I_I" being "implies_inverse".
    ['foo (= 1.0)', 'foo (= 2.0)', 0, 1, 0, 1, __LINE__],
    ['foo (>= 1.0)', 'foo (= 2.0)', undef, undef, 1, 0, __LINE__],
    ['foo (>= 2.0)', 'foo (>= 1.0)', 1, 0, undef, undef, __LINE__],
    ['foo (>> 1.0)', 'foo (>= 1.0)', 1, 0, undef, undef, __LINE__],
    ['foo (>> 2.0)', 'foo (>> 1.0)', 1, 0, undef, undef, __LINE__],
    ['foo (<= 1.0)', 'foo (<= 2.0)', 1, 0, undef, undef, __LINE__],
    ['foo (<< 1.0)', 'foo (<= 1.0)', 1, 0, undef, undef, __LINE__],
    ['foo (<< 1.0)', 'foo (<< 2.0)', 1, 0, undef, undef, __LINE__],
);

plan tests => scalar(@TESTS) * 4;

for my $test (@TESTS) {
    my ($a_raw, $b_raw, $a_i_b, $a_ii_b, $b_i_a, $b_ii_a, $lno) = @{$test};
    my $a = Lintian::Relation->new($a_raw);
    my $b = Lintian::Relation->new($b_raw);
    is($a->implies($b), $a_i_b, "$a_raw implies $b_raw (case 1, line $lno)");
    is($a->implies_inverse($b),
        $a_ii_b, "$test->[0] implies inverse $test->[1] (case 2, line $lno)");

    is($b->implies($a), $b_i_a,
        "$b_raw implies $a_raw (case 3, line $test->[6])");
    is($b->implies_inverse($a),
        $b_ii_a, "$b_raw implies inverse $a_raw (case 4, line $lno)");
}


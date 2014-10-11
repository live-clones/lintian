#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Lintian::Relation;

test_relation(
    'pkg%any (>= 1.0)  ,  pkgB   |  1gf  ,  pkgC(>=2.0)',
    'implied' => [
        'pkgB | 1gf', # partly unparsable, but identity holds
        'pkgC (>= 1.0)', # regular entry
    ],
    'not-implied' => [
        'pkg',     # unparsable
        'pkg%any', # unparsable
        'pkgB',    # OR relation with unparsable entry
        '1gf',     # OR relation
    ],
    'unparsed' => 'pkg%any (>= 1.0), pkgB | 1gf, pkgC (>= 2.0)'
);

done_testing;

sub test_relation {
    my ($str, %tests) = @_;
    my $rel = Lintian::Relation->new($str);
    my $tests = 0;
    if (my $unparsed = $tests{'unparsed'}) {
        is($rel->unparse, $unparsed, "Unparse $str");
        $tests++;
    }
    if (my $implications = $tests{'implied'}) {
        for my $imp (@{$implications}) {
            my $test = qq{"$str" implies "$imp"};
            ok($rel->implies($imp), $test);
            $tests++;
        }
    }

    if (my $non_implications = $tests{'not-implied'}) {
        for my $no_imp (@{$non_implications}) {
            my $test = qq{"$str" does NOT imply "$no_imp"};
            ok(!$rel->implies($no_imp), $test);
            $tests++;
        }
    }
    cmp_ok($tests, '>=', 1, qq{Ran at least on test on "$str"});
    return;
}


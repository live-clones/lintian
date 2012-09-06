#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

BEGIN { use_ok('Lintian::Util', qw(parse_boolean)); }

my @truth_vals = (qw(
   YES
   y
   TrUE
   1 10 1 01
));

my @false_vals = (qw(
   No
   n
   0 00
));

my @not_bools = ('', 'random-string', ' 0', '0 ', '1 ', ' 1');

foreach my $truth (@truth_vals) {
    eval {
        ok (parse_boolean ($truth), "$truth should be true value");
    };
    fail ("$truth should be parsable as a bool") if $@;
}

foreach my $false (@false_vals) {
    eval {
        ok (! parse_boolean ($false), "$false should be false");
    };
    fail ("$false should be parsable as a bool") if $@;
}

foreach my $not_bool (@not_bools) {
    eval {
        parse_boolean ($not_bool);
        fail ("$not_bool should not be parsed as a bool");
    };
    if ($@) {
        pass ("$not_bool is not a boolean");
    }
}

plan tests => (1 + scalar @truth_vals +
    scalar @false_vals +
    scalar @not_bools);

#! /usr/bin/perl

use strict;
use warnings;

use Const::Fast;
use Test::More tests => 13;

use Lintian::Relation::Version qw(:all);

const my $EQUAL => q{=};

ok(versions_equal('1.0', '1.0'), 'Basic equality');
ok(versions_equal('1.0', '1.00'), '0 == 00');
ok(versions_gte('1.1', '1.0'), 'Basic >=');
ok(!versions_lte('1.1', '1.0'), 'Basic <=');
ok(versions_gt('1.1', '1.0'), 'Basic >');
ok(!versions_lt('1.1', '1.1'), 'Basic <');

ok(versions_compare('1.1', '<=', '1.1'), 'compare() <=');
ok(versions_compare('1.2', '>=', '1.1'), 'compare() >=');
ok(versions_compare('0:1-1', $EQUAL, '1-1'), 'compare() = with epoch 0');
ok(versions_compare('2.3~', '<<', '2.3'), 'compare() << with tilde');
ok(!versions_compare('1:1.0', '>>', '1:1.1'), 'compare() >> with equal epoch');
ok(
    !versions_compare('1:1.1', '>>', '2:1.0'),
    'compare() >> with different epochs'
);
ok(
    versions_compare('1:1.1', '<<', '2:1.1'),
    'compare() << with different epochs'
);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

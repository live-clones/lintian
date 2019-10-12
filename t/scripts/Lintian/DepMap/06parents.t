#!/usr/bin/perl

use warnings;
use strict;
use Test::More tests => 2;

use Lintian::DepMap;

my $map = Lintian::DepMap->new;

$map->add('A');
$map->add('B', 'A');

my @parents;
ok(eval {@parents = $map->parents('B'); }, q{Get B's parents});
is_deeply(\@parents, ['A'], q{B's parent is A});

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

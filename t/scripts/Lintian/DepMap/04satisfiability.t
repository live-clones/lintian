#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 4;

use Lintian::DepMap;

my $obj = Lintian::DepMap->new;

ok($obj->add('A', 'B'), 'Nodes can be added in any order');

eval {$obj->satisfy('Z')};
isnt($@, '', 'Nodes that were not added cannot be satisfied');

eval {$obj->satisfy('B')};
isnt($@, '','Nodes that were not added and are missing() cannot be satisfied');

ok(!$obj->satisfy('A'),
    'Nodes cannot be satisfied if they still have dependencies');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

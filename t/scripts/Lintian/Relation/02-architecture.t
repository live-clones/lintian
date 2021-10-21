#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::Relation;

my $relation
  = Lintian::Relation->new->load_norestriction('pkgA [i386], pkgB [amd64]');

ok($relation->satisfies('pkgA'),  'Implies arch alt [i386]');
ok($relation->satisfies('pkgB'),  'Implies arch alt [amd64]');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

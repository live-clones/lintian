#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Lintian::Lab::Manifest;

my $DATADIR = $0;
$DATADIR =~ s,[^/]+$,,o;
if ($DATADIR) {
    # invokved in some other dir
    $DATADIR = "$DATADIR/data";
} else {
    # current dir
    $DATADIR = 'data';
}

plan skip_all => 'Data files not available'
  unless -d $DATADIR;

my $origm = Lintian::Lab::Manifest->new('changes');
my $newm  = Lintian::Lab::Manifest->new('changes');
my $diff;

my ($added, $changed, $removed);

$origm->read_list("$DATADIR/orig-list-info");
$newm->read_list("$DATADIR/new-list-info");

$diff = $origm->diff($newm);

# We are good to go :)
plan tests => 12;

$added   = $diff->added;
$changed = $diff->changed;
$removed = $diff->removed;

# Do we get the expected amount of changes ?
is(@{$added}, 1, 'One new package');
is(@{$changed}, 1, 'One changed package');
is(@{$removed}, 1, 'One removed package');

# Are the names of the packages involved in the changes correct?
is($added->[0][0], 'newpkg', 'The new package is "newpkg"');
is($changed->[0][0], 'modpkg', 'The changed package is "modpkg"');
is($removed->[0][0], 'oldpkg', 'The removed package is "oldpkg"');

# Do the change packages appear in the right lists?
ok($newm->get(@{ $added->[0] }),
    'The new package can be looked up in new-list');
is($origm->get(@{ $added->[0] }),
    undef, 'The new package cannot be looked up in orig-list');

ok($newm->get(@{ $changed->[0] }),
    'The changed package can be looked up in new-list');
ok($origm->get(@{ $changed->[0] }),
    'The changed package can be looked up in orig-list');

is($newm->get(@{ $removed->[0] }),
    undef, 'The old package cannot be looked up in new-list');
ok($origm->get(@{ $removed->[0] }),
    'The old package can be looked up in orig-list');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

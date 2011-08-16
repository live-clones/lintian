#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Lintian::Internal::PackageList;

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

plan tests => 9;

my $plist = Lintian::Internal::PackageList->new('changes');
my $olist = Lintian::Internal::PackageList->new('changes');
$plist->read_list("$DATADIR/changes1-info");
my @all = sort $plist->get_all;
my @oall;
my $inmemdata;

is( @all, 3, "Read 3 elements from the data file");
for ( my $i = 0; $i < scalar @all; $i++) {
    my $no = $i + 1;
    is($all[$i], "pkg$no", "The first element is pkg$no");
}

ok( eval {
    $plist->write_list(\$inmemdata);
    $olist->read_list(\$inmemdata);
    1;
}, "Wrote and read the data");

SKIP: {
    if ($@) {
        diag("Write/Read issue: $@");
        skip 'Write test failed; the rest of the tests will not work', 4;
    }
    @oall = sort $olist->get_all;
    is_deeply(\@all, \@oall, "The lists contents the same elements");
    for ( my $i = 0 ; $i < scalar @all ; $i++) {
        my $no = $i + 1;
        my $e  = $plist->get($all[$i]);
        my $oe = $olist->get($all[$i]);
        is_deeply($e, $oe, "Element no. $no are identical");
    }
}


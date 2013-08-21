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

plan tests => 9;

my $plist = Lintian::Lab::Manifest->new('changes');
my $olist = Lintian::Lab::Manifest->new('changes');
$plist->read_list("$DATADIR/changes1-info");
my @all;
my $inmemdata;

$plist->visit_all(sub { push @all, $_[1] });

is(@all, 3, 'Read 3 elements from the data file');
for (my $i = 0; $i < scalar @all; $i++) {
    my $no = $i + 1;
    is($all[$i], "pkg$no", "Element $no is pkg$no");
}

ok(
    eval {
        $plist->write_list(\$inmemdata);
        $olist->read_list(\$inmemdata);
        1;
    },
    'Wrote and read the data'
);

SKIP: {
    my @pkeys;
    my @pval;
    my @oval;
    my $pv = sub { my ($v, @k) = @_; push @pval, $v; push @pkeys, \@k };
    my $ov = sub { push @oval, $_[0] };
    if ($@) {
        diag("Write/Read issue: $@");
        skip 'Write test failed; the rest of the tests will not work', 4;
    }
    $plist->visit_all($pv);
    $olist->visit_all($ov);
    is_deeply(\@pval, \@oval, 'The lists contents the same elements');
    for (my $i = 0 ; $i < scalar @pkeys ; $i++) {
        my $no = $i + 1;
        my $e  = $plist->get(@{ $pkeys[$i] });
        my $oe = $olist->get(@{ $pkeys[$i] });
        is_deeply($e, $oe, "Element no. $no are identical");
    }
}


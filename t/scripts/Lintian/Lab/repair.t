#!/usr/bin/perl

use strict;
use warnings;
use autodie qw(opendir closedir);

use Test::More;
use Lintian::Lab;
use Lintian::Lab::Manifest;
use Lintian::Processable::Package;

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
plan tests => 2;

my $LAB_A = Lintian::Lab->new;
my $LAB_B = Lintian::Lab->new;
my $err = undef;
eval {
    $LAB_A->create ({ 'keep-lab' => 1});
    $LAB_B->create ({ 'keep-lab' => 1});

    subtest 'Lab test' => \&do_tests;
};
$err = $@ if $@;

$LAB_A->remove if $LAB_A->exists;
$LAB_B->remove if $LAB_B->exists;

is ($err, undef, 'Test had no errors');

exit 0;

sub do_tests {
    # The grand scheme of things; import packages into Lab A.  Check
    # that repair is "non-destructive" on a "good lab". Then close it;
    # swap the manifests of Lab A and B.  Now they will both be wrong.
    #
    # Repair of A should result in the manifest being restored and repair
    # of B should result in the Lab being empty.

    my $full_manifest;
    my $empty_manifest;
    my $diff;
    my $added = 0;

    $LAB_A->open;

    $empty_manifest = $LAB_A->_get_lab_index ('changes')->clone;

    opendir(my $dirfd, "$DATADIR/changes");
    foreach my $pkgbase (readdir $dirfd) {
        next unless $pkgbase =~ m/\.(?:changes|u?deb|dsc)$/;
        my $path = "$DATADIR/changes/$pkgbase";
        my $proc = Lintian::Processable::Package->new ($path);
        my $entry = $LAB_A->get_package ($proc);
        $entry->create;
        $added++;
    }
    closedir($dirfd);

    $full_manifest = $LAB_A->_get_lab_index ('changes')->clone;

    $LAB_A->close;

    $diff = $empty_manifest->diff ($full_manifest);
    cmp_ok (scalar @{ $diff->added }, '==', $added, 'Packages have been added to the lab');
    $diff = undef;

    # Test that repair is non-destructive on a "mint condition" lab.
    $LAB_A->open;
    $LAB_A->repair;

    $diff = $full_manifest->diff ($LAB_A->_get_lab_index ('changes'));
    cmp_ok (scalar @{ $diff->added }, '==', 0, 'Lab A (mint): new appeared with repair');
    cmp_ok (scalar @{ $diff->removed }, '==', 0, 'Lab A (mint): Nothing disappeared with repair');
    # Currently nothing changes (no pun intended) when repairing; it might in the
    # future, but for now disallow it.
    cmp_ok (scalar @{ $diff->changed }, '==', 0, 'Lab A (mint): Nothing changed with repair');

    $LAB_A->close;
    $diff = undef;

    # Time for the swap

    rename $LAB_A->dir . '/pool', $LAB_A->dir . '/pool-old' or die "rename LAB_A pool: $!";
    rename $LAB_B->dir . '/pool', $LAB_A->dir . '/pool' or die "rename LAB_B -> LAB_A pool: $!";
    rename $LAB_A->dir . '/pool-old', $LAB_B->dir . '/pool' or die "rename LAB_A -> LAB_B pool: $!";

    # Test that repair restores entries that are available
    $LAB_A->open;
    $LAB_A->repair;

    $diff = $full_manifest->diff ($LAB_A->_get_lab_index ('changes'));
    cmp_ok (scalar @{ $diff->added }, '==', 0, 'Lab A (broken): Nothing new appeared with repair');
    TODO: {
        local $TODO = 'Restoration not implemented yet';
        cmp_ok (scalar @{ $diff->removed }, '==', 0, 'Lab A (broken): Nothing disappeared with repair');
    }
    # Currently nothing changes (no pun intended) when repairing; it might in the
    # future, but for now disallow it.
    cmp_ok (scalar @{ $diff->changed }, '==', 0, 'Lab A (broken): Nothing changed with repair');

    $LAB_A->close;
    $diff = undef;


    # Test that repair prunes missing entries from the manifest
    $LAB_B->open;
    $LAB_B->repair;

    $diff = $empty_manifest->diff ($LAB_B->_get_lab_index ('changes'));
    cmp_ok (scalar @{ $diff->added }, '==', 0, 'Lab B: Nothing new appeared with repair');
    cmp_ok (scalar @{ $diff->removed }, '==', 0, 'Lab B: Nothing disappeared with repair');
    # Currently nothing changes (no pun intended) when repairing; it might in the
    # future, but for now disallow it.
    cmp_ok (scalar @{ $diff->changed }, '==', 0, 'Lab B: Nothing changed with repair');

    $LAB_B->close;

    done_testing;
}

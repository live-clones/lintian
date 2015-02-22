#!/usr/bin/perl

use strict;
use warnings;
use autodie qw(opendir closedir);

use Test::More;
use Lintian::Lab;
use Lintian::Lab::Manifest;
use Lintian::Processable::Package;
use Lintian::Util qw(delete_dir);

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

my $LAB = Lintian::Lab->new;
my $err = undef;
eval {
    $LAB->create({ 'keep-lab' => 1});

    subtest 'Lab test' => \&do_tests;
};
$err = $@ if $@;

$LAB->remove if $LAB->exists;

is($err, undef, 'Test had no errors');

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

    $LAB->open;

    $empty_manifest = $LAB->_get_lab_index('changes')->clone;

    opendir(my $dirfd, "$DATADIR/changes");
    foreach my $pkgbase (readdir $dirfd) {
        next unless $pkgbase =~ m/\.(?:changes|u?deb|dsc)$/;
        my $path = "$DATADIR/changes/$pkgbase";
        my $proc = Lintian::Processable::Package->new($path);
        my $entry = $LAB->get_package($proc);
        $entry->create;
        $added++;
    }
    closedir($dirfd);

    $full_manifest = $LAB->_get_lab_index('changes')->clone;

    $LAB->close;

    $diff = $empty_manifest->diff($full_manifest);
    cmp_ok(scalar @{ $diff->added },
        '==', $added, 'Packages have been added to the lab');
    $diff = undef;

    # Time for some destruction

    delete_dir($LAB->dir . '/pool/l')
      or die "rename LAB pool: $!";

    # Test that auto repair discards missing entries as they are
    # discovered.
    $LAB->open;
    my $entry = $LAB->get_package('lintian', 'changes', '2.5.8');
    is($entry, undef, 'Broken entries are not returned');

    $diff = $full_manifest->diff($LAB->_get_lab_index('changes'));
    cmp_ok(scalar @{ $diff->removed },
        '==', 1, 'One entry is auto-fixed (match 1 entry)');
    my $previous_state = $LAB->_get_lab_index('changes')->clone;

    my @entries = $LAB->get_package('lintian', 'changes', '2.5.10');
    is(scalar(@entries), 0, 'Broken entries are not returned');

    $diff = $previous_state->diff($LAB->_get_lab_index('changes'));
    cmp_ok(scalar @{ $diff->removed },
        '==', 2, 'Two entries are fixed (match 2 entries)');
    $previous_state = $LAB->_get_lab_index('changes')->clone;

    my $number_visited = 0;
    $LAB->visit_packages(sub { $number_visited++; }, 'changes');
    cmp_ok($number_visited, '==', 0, 'We do not visit broken entries');

    # The lab should now be empty
    $diff = $empty_manifest->diff($LAB->_get_lab_index('changes'));
    cmp_ok(scalar @{ $diff->added },
        '==', 0, 'Post visit, lab is now empty (added)');
    cmp_ok(scalar @{ $diff->removed },
        '==', 0, 'Post visit, lab is now empty (removed)');
    cmp_ok(scalar @{ $diff->changed },
        '==', 0, 'Post visit, lab is now empty (changed)');

    $LAB->close;

    return done_testing;
}

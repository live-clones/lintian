#!/usr/bin/perl

use strict;
use Test::More;

sub should_skip($);

plan skip_all => 'Only UNRELEASED versions are criticised'
    if should_skip($ENV{'LINTIAN_ROOT'});

eval 'use Test::Perl::Critic 1.00';
plan skip_all => "Test::Perl::Critic 1.00 required to run this test" if $@;

eval 'use PPIx::Regexp';
diag('libppix-regexp-perl is needed to enable some checks') if $@;

Test::Perl::Critic->import( -profile => "$ENV{LINTIAN_ROOT}/.perlcriticrc" );

all_critic_ok("$ENV{LINTIAN_ROOT}/checks",
	      "$ENV{LINTIAN_ROOT}/lib",
	      "$ENV{LINTIAN_ROOT}/collection");


sub should_skip($) {
    my $path = shift;
    my $skip = 1;
    my $pid;

    $pid = open (DPKG, '-|', 'dpkg-parsechangelog', '-c0',
	    "-l$path/debian/changelog");

    die("failed to execute dpkg-parsechangelog: $!")
	unless defined ($pid);
    
    while (<DPKG>) {
	$skip = 0 if m/^Distribution: UNRELEASED$/;
    }

    close(DPKG)
	or die ("dpkg-parsechangelog returned: $?");

    return $skip;
}

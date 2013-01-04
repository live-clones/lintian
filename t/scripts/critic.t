#!/usr/bin/perl

use strict;
use Test::More;

sub should_skip();


chdir ($ENV{'LINTIAN_ROOT'})
    or die ("fatal error: could not chdir to $ENV{LINTIAN_ROOT}: $!");

plan skip_all => 'Only UNRELEASED versions are criticised'
    if should_skip();


eval 'use Test::Perl::Critic 1.00';
plan skip_all => "Test::Perl::Critic 1.00 required to run this test" if $@;

eval 'use PPIx::Regexp';
diag('libppix-regexp-perl is needed to enable some checks') if $@;


Test::Perl::Critic->import( -profile => '.perlcriticrc' );


our @CHECKS = glob ('checks/*[!.]*[!c]');
plan tests => scalar(@CHECKS)+1;

for my $check (@CHECKS) {
    critic_ok($check);
}

subtest 'All scripts with correct shebang or extension' => sub {
    all_critic_ok(qw(collection frontend lib));
};

sub should_skip() {
    my $skip = 1;
    my $pid;

    return $skip unless (defined ($ENV{'CRITICISE'}));

    $pid = open (DPKG, '-|', 'dpkg-parsechangelog', '-c0');

    die("failed to execute dpkg-parsechangelog: $!")
	unless defined ($pid);
    
    while (<DPKG>) {
	$skip = 0 if m/^Distribution: UNRELEASED$/;
    }

    close(DPKG)
	or die ("dpkg-parsechangelog returned: $?");

    return $skip;
}

#!/usr/bin/perl

use strict;
use warnings;
use autodie;

use Test::More;


chdir($ENV{'LINTIAN_ROOT'});

plan skip_all => 'Only UNRELEASED versions are criticised'
    if should_skip();


eval 'use Test::Perl::Critic 1.00';
plan skip_all => 'Test::Perl::Critic 1.00 required to run this test' if $@;

eval 'use PPIx::Regexp';
diag('libppix-regexp-perl is needed to enable some checks') if $@;


Test::Perl::Critic->import( -profile => '.perlcriticrc' );


our @CHECKS = glob ('checks/*[!.]*[!c]');
plan tests => scalar(@CHECKS)+2;

for my $check (@CHECKS) {
    critic_ok($check);
}

critic_ok('t/runtests');

subtest 'All scripts with correct shebang or extension' => sub {
    all_critic_ok(qw(collection frontend lib private reporting t/scripts t/helpers));
};

sub should_skip {
    my $skip = 1;

    open(my $fd, '-|', 'dpkg-parsechangelog', '-c0');

    while (<$fd>) {
	$skip = 0 if m/^Distribution: UNRELEASED$/;
    }

    close($fd);

    return $skip;
}

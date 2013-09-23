#!/usr/bin/perl

package critic;
use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Test::More;

our @EXPORT_OK = qw(run_critic);

plan skip_all => 'Only UNRELEASED versions are criticised'
  if should_skip();

eval 'use Test::Perl::Critic 1.00';
plan skip_all => 'Test::Perl::Critic 1.00 required to run this test' if $@;

eval 'use PPIx::Regexp';
diag('libppix-regexp-perl is needed to enable some checks') if $@;

$ENV{'LINTIAN_TEST_ROOT'} //= '.';
my $critic_profile = "$ENV{'LINTIAN_TEST_ROOT'}/.perlcriticrc";
Test::Perl::Critic->import(-profile => $critic_profile);

sub run_critic {
    my (@args) = @_;
    plan tests => scalar(@args);
    for my $arg (@args) {
        if (-d $arg) {

            # all_critic_ok emits its own plan, so run it in a subtest
            # so we can just count it as "one" test.
            subtest "Critic all code in $arg" => sub {
                all_critic_ok($arg);
            };
        }elsif (-f _ ) {
            critic_ok($arg);
        }else {
            die "$arg does not exists\n" if not -e _;
            die "$arg is of an unsupported file type\n";
        }
    }
    return 1;
}

sub should_skip {
    my $skip = 1;

    open(my $fd, '-|', 'dpkg-parsechangelog', '-c0');

    while (<$fd>) {
        $skip = 0 if m/^Distribution: UNRELEASED$/;
    }

    close($fd);

    return $skip;
}

1;

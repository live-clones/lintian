#!/usr/bin/perl

# Simple critic test runner that guesses it task from $0.
# NB: If you change anything in this script, consider if
# others.t need an update as well.

use strict;
use warnings;

use Const::Fast;
use IPC::Run3;
use POSIX qw(ENOENT);

use
  if $ENV{'LINTIAN_COVERAGE'}, 'Test::More',
  'skip_all' => 'Not needed for coverage of Lintian';

use Test::Lintian;
use Test::More;

plan skip_all => 'Only UNRELEASED versions are criticised'
  if should_skip();

eval 'use Test::Perl::Critic 1.00';
plan skip_all => 'Test::Perl::Critic 1.00 required to run this test' if $@;

eval 'use Perl::Tidy 20181120';
# Actually we could just disable the perltidy check, but I am not
# sure how to do that without making it ignore our perlcriticrc file.
plan skip_all => 'Perl::Tidy 20180220 required to run this test' if $@;

eval 'use PPIx::Regexp';
diag('libppix-regexp-perl is needed to enable some checks') if $@;

const my $DOT => q{.};

my @test_paths = program_name_to_perl_paths($0);
$ENV{'LINTIAN_BASE'} //= $DOT;
my $critic_profile = "$ENV{'LINTIAN_BASE'}/.perlcriticrc";
Test::Perl::Critic->import(-profile => $critic_profile);

run_critic(@test_paths);

exit(0);

sub run_critic {
    my (@args) = @_;

    all_critic_ok(@args);

    # For some reason, perltidy has started to leave behind a
    # "perltidy.LOG" which is rather annoying.  Lets have the tests
    # unconditionally kill those.
    my $err = unlink('perltidy.LOG');
    if ($err) {
        # Since this test is run in parallel, there is an
        # race-condition between checking for the file and actually
        # deleting.  So just remove the file and ignore ENOENT
        # problems.
        die($err) if $err->errno != ENOENT;
    }
    return 1;
}

sub should_skip {
    my $skip = 1;

    my @command = qw{dpkg-parsechangelog -c0};
    my $output;

    run3(\@command, \undef, \$output);

    $skip = 0
      if $output =~ /^Distribution: UNRELEASED$/m;

    return $skip;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

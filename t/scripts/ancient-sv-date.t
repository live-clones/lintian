#!/usr/bin/perl
#
# Test for keeping "ancient standards version" date
# recent.
#

use strict;
use warnings;
use autodie;

use Test::More;

# How much out of date the check may be; measured in seconds
# 1 month
use constant ERROR_MARGIN => 3600 * 24 * 31;
# How long before a SV is considered "Ancient" in seconds.
# 2 years.
use constant ANCIENT_AGE  => 3600 * 24 * 365 * 2;
use Date::Parse qw(str2time);

# STOP! Before you even consider to make this run always
# remember that this test will fail (causing FTBFS) every
# "ERROR_MARGIN" seconds!
#   This check is here to remind us to update ANCIENT_DATE
# in checks/standards-version every now and then during
# development cycles!
plan skip_all => 'Only checked for UNRELEASED versions'
  if should_skip();

plan tests => 2;

$ENV{'LINTIAN_TEST_ROOT'} //= '.';

my $check = "$ENV{'LINTIAN_TEST_ROOT'}/data/standards-version/ancient-date";
my $found = 0;
open(my $fd, '<', $check);
while (my $line = <$fd>) {
    # We are looking for:
    #   my $ANCIENT_DATE < '20 Aug 2009')
    $line =~ s,\#.*+,,o;
    if (
        $line =~ m/ANCIENT \s* < \s*
                  ([\s\w]+)/ox
      ) {
        my $date = $1;
        my $and = str2time($date)
          or die "Cannot parse date ($date, line $.): $!";
        my $time = time - ANCIENT_AGE;
        $found = 1;
        cmp_ok($time, '<', $and + ERROR_MARGIN, 'ANCIENT_DATE is up to date');
        cmp_ok(
            $time, '>',
            $and - ERROR_MARGIN,
            'ANCIENT_DATE is not too far ahead'
        );
        last;
    }
}
close($fd);

die "Cannot find ANCIENT_DATE.\n" unless $found;

sub should_skip {
    my $skip = 1;

    open(my $fd, '-|', 'dpkg-parsechangelog', '-c0');

    while (<$fd>) {
        $skip = 0 if m/^Distribution: UNRELEASED$/;
    }

    close($fd);

    return $skip;
}


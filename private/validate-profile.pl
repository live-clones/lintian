#!/usr/bin/perl

use strict;
use warnings;

use lib "$ENV{LINTIAN_ROOT}/lib";

use Lintian::Profile;

my $ppath = [
    "$ENV{LINTIAN_ROOT}/profiles"
    ];

foreach my $name (@ARGV) {
    my $profile = Lintian::Profile->new($name, $ppath);
    my $pname = $profile->name;
    my $parents = $profile->parents;
    my @tags = $profile->tags;
    if (scalar @$parents) {
        print "$pname extends " . join(', ', @$parents) . "\n";
    } else {
        print "$pname is a stand-alone profile\n";
    }
    print "$pname has " . scalar(@tags) . " tags.\n";
}
exit 0;

#! /usr/bin/perl -w

use strict;

BEGIN {
  # determine LINTIAN_ROOT
  my $LINTIAN_ROOT = $ENV{'LINTIAN_ROOT'} || '/usr/share/lintian';
  $ENV{'LINTIAN_ROOT'} = $LINTIAN_ROOT
    unless exists $ENV{'LINTIAN_ROOT'};
}

use lib "$ENV{'LINTIAN_ROOT'}/lib";
use Util;

my $problems = 0;

for my $f (<$ENV{'LINTIAN_ROOT'}/checks/*.desc>) {
    my @sections = read_dpkg_control($f);
    for (my $i = 0; $i <= $#sections; $i++) {
	if (exists $sections[$i]->{'tag'}) {
	    if (not exists $sections[$i]->{'info'}) {
		print "E: no info for $sections[$i]->{'tag'} in $f\n";
		$problems++;
	    }
	}
    }
}

if ($problems) {
    print "Found $problems missing info section(s)\n";
    exit(-1);
}

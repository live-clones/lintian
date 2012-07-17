# -*- perl -*-
# Lintian::Internal::FrontendUtil -- internal helpers for lintian frontends

# Copyright (C) 2011 Niels Thykier
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Internal::FrontendUtil;
use strict;
use warnings;

use base qw(Exporter);

use Dpkg::Vendor;

use Lintian::CollScript;
use Lintian::Util qw(check_path fail);

our @EXPORT = qw(check_test_feature default_parallel find_default_profile load_collections);

# Check if we are testing a specific feature
#  - e.g. vendor-libdpkg-perl
sub check_test_feature{
    my $env = $ENV{LINTIAN_TEST_FEATURE};
    return 0 unless $env;
    foreach my $feat (@_){
        return 1 if($env =~ m/$feat/);
    }
    return 0;
}

# find_default_profile(@prof_path)
#
# locates the default profile - used if no profile was explicitly given.
sub find_default_profile {
    my (@prof_path) = @_;
    my $vendor = Dpkg::Vendor::get_current_vendor();
    fail "Could not determine the current vendor.\n"
        unless $vendor;
    my $orig = $vendor; # copy
    while ($vendor) {
        my $p;
        $p = Lintian::Profile->find_profile(lc($vendor), @prof_path);
        last if $p;
        my $info = Dpkg::Vendor::get_vendor_info ($vendor);
        # Cannot happen atm, but in case Dpkg::Vendor changes its internals
        #  or our code changes
        fail "Could not look up the parent vendor of $vendor.\n"
            unless $info;
        $vendor = $info->{'Parent'};
    }
    fail("Could not find a profile for vendor $orig") unless $vendor;
    return lc($vendor);
}

# load_collections ($visitor, $dirname)
#
# Load collections from $dirname and pass them to $visitor.  $visitor
# will be called once per collection as it has been loaded.  The first
# (and only) argument to $visitor is the collection as an instance of
# Lintian::CollScript instance.
sub load_collections {
    my ($visitor, $dirname) = @_;

    opendir my $dir, $dirname
        or fail "cannot read directory $dirname: $!";

    foreach my $file (readdir $dir) {
        next if $file =~ m/^\./;
        next unless $file =~ m/\.desc$/;
        my $cs = Lintian::CollScript->new ("$dirname/$file");
        $visitor->($cs);
    }

    closedir $dir;
}

# Return the default number of parallization to be used
sub default_parallel {
    # check cpuinfo for the number of cores...
    my $cpus;
    chomp ( $cpus = `nproc 2>&1` );
    if ($? == 0 and $cpus =~ m/^\d+$/ ) {
        # Running up to twice the number of cores usually gets the most out
        # of the CPUs and disks but it might be too aggresive to be the
        # default for -j. Only use <cores>+1 then.
        return $cpus + 1;
    }

    # No decent number of jobs? Just use 2 as a default
    return 2;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

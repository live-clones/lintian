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
use autodie qw(opendir closedir);

use Exporter qw(import);

use Dpkg::Vendor;

use Lintian::CollScript;
use Lintian::Util qw(check_path fail);

our @EXPORT_OK
  = qw(check_test_feature default_parallel load_collections split_tag
  determine_locale);

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

# determine_locale
#
# Guess which language should be used based on environment variables.
#
# Note this will look at and return the contents of LC_ALL or
# LC_MESSAGES etc. if one of these are set.
#
# If suitable variable is set, this will return "C.UTF-8" as fallback.
#
sub determine_locale {
    for my $var (qw(LC_ALL LC_MESSAGES LANG)) {
        return $ENV{$var} if exists($ENV{$var}) and $ENV{$var} ne '';
    }
    return 'C.UTF-8';
}

# load_collections ($visitor, $dirname)
#
# Load collections from $dirname and pass them to $visitor.  $visitor
# will be called once per collection as it has been loaded.  The first
# (and only) argument to $visitor is the collection as an instance of
# Lintian::CollScript instance.
sub load_collections {
    my ($visitor, $dirname) = @_;

    opendir(my $dir, $dirname);

    foreach my $file (readdir $dir) {
        next if $file =~ m/^\./;
        next unless $file =~ m/\.desc$/;
        my $cs = Lintian::CollScript->new("$dirname/$file");
        $visitor->($cs);
    }

    closedir($dir);
    return;
}

# Return the default number of parallization to be used
sub default_parallel {
    # check cpuinfo for the number of cores...
    my $cpus;
    chomp($cpus = `nproc 2>&1`);
    if ($? == 0 and $cpus =~ m/^\d+$/) {
        # Running up to twice the number of cores usually gets the most out
        # of the CPUs and disks but it might be too aggresive to be the
        # default for -j. Only use <cores>+1 then.
        return $cpus + 1;
    }

    # No decent number of jobs? Just use 2 as a default
    return 2;
}

{
    # Matches something like:  (1:2.0-3) [arch1 arch2]
    # - captures the version and the architectures
    my $verarchre = qr,(?: \s* \(( [^)]++ )\) \s* \[ ( [^]]++ ) \]),xo;
    #                             ^^^^^^^^          ^^^^^^^^^^^^
    #                           ( version   )      [architecture ]

    # matches the full deal:
    #    1  222 3333  4444444   5555   666  777
    # -  T: pkg type (version) [arch]: tag [...]
    #           ^^^^^^^^^^^^^^^^^^^^^
    # Where the marked part(s) are optional values.  The numbers above
    # the example are the capture groups.
    my $TAG_REGEX
      = qr/([EWIXOP]): (\S+)(?: (\S+)(?:$verarchre)?)?: (\S+)(?:\s+(.*))?/o;

    sub split_tag {
        my ($tag_input) = @_;
        my $pkg_type;
        return unless $tag_input =~ m/^${TAG_REGEX}$/o;
        # default value...
        $pkg_type = $3//'binary';
        return ($1, $2, $pkg_type, $4, $5, $6, $7);
    }
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

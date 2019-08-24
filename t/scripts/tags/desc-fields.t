#!/usr/bin/perl

# Copyright © 2019 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

# The harness for Lintian's test suite.  For detailed information on
# the test suite layout and naming conventions, see t/tests/README.
# For more information about running tests, see
# doc/tutorial/Lintian/Tutorial/TestSuite.pod
#

use strict;
use warnings;
use autodie;
use v5.10;

use File::Find::Rule;
use List::Util qw(all);
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_TEST_ROOT'}/lib";

use Lintian::Profile;
use Test::Lintian::ConfigFile qw(read_config);

use constant SPACE => q{ };
use constant EMPTY => q{};

my @descpaths = File::Find::Rule->file()->name('*.desc')->in('tags');

diag scalar @descpaths . ' known tags.';

# mandatory fields
my @mandatory = qw(tag severity certainty check info);

# disallowed fields
my @disallowed = qw();

# tests per desc
my $perfile = 6 + scalar @mandatory + scalar @disallowed;

# set the testing plan
my $known_tests = $perfile * scalar @descpaths;

my $profile = Lintian::Profile->new(undef, [$ENV{LINTIAN_ROOT}]);

foreach my $descpath (@descpaths) {

    # test for duplicate fields
    my %count;
    my @lines = path($descpath)->lines;
    foreach my $line (@lines) {
        my ($field) = $line =~ qr/^(\S+):/;
        $count{$field} += 1
          if defined $field;
    }
    ok(
        (all { $count{$_} == 1 } keys %count),
        "No duplicate fields in $descpath"
    );

    my $info = read_config($descpath);

    # tag has a name
    my $tagname = $info->{tag};
    BAIL_OUT("Tag described in $descpath has no name")
      unless length $tagname;

    # tagfile is named $tagname.desc
    is(path($descpath)->basename,
        "$tagname.desc", "Tagfile for $tagname is named $tagname.desc");

    # encapsulating directory is first letter of tag's name
    my $parentdir = path($descpath)->parent->basename;
    my $firstletter = lc(substr($tagname, 0, 1));
    is($parentdir, $firstletter,
        "Tag $tagname is in directory named '$firstletter'");

    # mandatory fields
    ok(exists $info->{$_}, "Field $_ exists in $descpath") for @mandatory;

    # disallowed fields
    ok(!exists $info->{$_}, "Field $_ does not exist in $descpath")
      for @disallowed;

    my $checkfield = $info->{check};

    # tag is associated with a check
    ok(length $checkfield, "Tag $tagname is associated with a check");

    $checkfield //= EMPTY;

    my ($checkname) = $checkfield  =~ qr/^(\S+)$/;

    # tag is associated with a single check
    ok(length $checkname, "Tag $tagname is associated with a single check");

    $checkname //= EMPTY;

    ok($profile->get_script($checkname),
        "Tag $tagname is associated with a valid check");
}

done_testing($known_tests);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

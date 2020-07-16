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

use Lintian::Deb822::File;
use Lintian::Profile;

use constant EMPTY => q{};
use constant SPACE => q{ };

my @descpaths = sort File::Find::Rule->file()->name('*.desc')->in('tags');

diag scalar @descpaths . ' known tags.';

# mandatory fields
my @mandatory = qw(Tag Severity Check Info);

# disallowed fields
my @disallowed = qw(Reference References);

# tests per desc
my $perfile = 7 + scalar @mandatory + scalar @disallowed;

# set the testing plan
plan tests => $perfile * scalar @descpaths;

my $profile = Lintian::Profile->new;
$profile->load(undef, [$ENV{LINTIAN_ROOT}]);

for my $descpath (@descpaths) {

    # test for duplicate fields
    my %count;

    my @lines = path($descpath)->lines;
    for my $line (@lines) {
        my ($field) = $line =~ qr/^(\S+):/;
        $count{$field} += 1
          if defined $field;
    }

    ok(
        (all { $count{$_} == 1 } keys %count),
        "No duplicate fields in $descpath"
    );

    my $deb822 = Lintian::Deb822::File->new;

    my @sections = $deb822->read_file($descpath);
    is(scalar @sections, 1, "Tag in $descpath has exactly one section");

    my $fields = $sections[0] // {};

    # tag has a name
    my $tagname = $fields->value('Tag');
    BAIL_OUT("Tag described in $descpath has no name")
      unless length $tagname;

    # tagfile is named $tagname.desc
    is(path($descpath)->basename,
        "$tagname.desc", "Tagfile for $tagname is named $tagname.desc");

    # mandatory fields
    ok(defined $fields->value($_), "Field $_ exists in $descpath")
      for @mandatory;

    # disallowed fields
    ok(!defined $fields->value($_), "Field $_ does not exist in $descpath")
      for @disallowed;

    my $checkname = $fields->value('Check') // EMPTY;

    # tag is associated with a check
    ok(length $checkname, "Tag $tagname is associated with a check");

    ok($profile->get_checkinfo($checkname),
        "Tag $tagname is associated with a valid check");

    if (($fields->value('Name-Spaced') // EMPTY) eq 'yes') {
        # encapsulating directory is name of check
        my $subdir = path($descpath)->parent->relative('tags');
        is($subdir, $checkname,
            "Tag $tagname is in directory named '$checkname'");

    } else {
        # encapsulating directory is first letter of tag's name
        my $parentdir = path($descpath)->parent->basename;
        my $firstletter = lc(substr($tagname, 0, 1));
        is($parentdir, $firstletter,
            "Tag $tagname is in directory named '$firstletter'");
    }

    ok(
        ($fields->value('Renamed-From') // EMPTY) !~ m{,},
        "Old tag names for $tagname are not separated by commas"
    );
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

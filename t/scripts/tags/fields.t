#!/usr/bin/perl

# Copyright © 2019-2020 Felix Lechner
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

use v5.20;
use warnings;
use utf8;
use autodie;

use File::Find::Rule;
use IPC::Run3;
use List::Util qw(all);
use Path::Tiny;
use Test::More;
use Unicode::UTF8 qw(encode_utf8);

use lib "$ENV{'LINTIAN_BASE'}/lib";

use Lintian::Deb822::File;
use Lintian::Output::HTML;
use Lintian::Profile;

use constant EMPTY => q{};
use constant SPACE => q{ };

my @tagpaths = sort File::Find::Rule->file()->name('*.tag')->in('tags');

diag scalar @tagpaths . ' known tags.';

# mandatory fields
my @mandatory = qw(Tag Severity Check Explanation);

# disallowed fields
my @disallowed = qw(Reference References Ref Info Certainty);

# tests per desc
my $perfile = 8 + scalar @mandatory + scalar @disallowed;

# set the testing plan
plan tests => $perfile * scalar @tagpaths;

my $profile = Lintian::Profile->new;
$profile->load(undef, [$ENV{LINTIAN_BASE}]);

for my $tagpath (@tagpaths) {

    # test for duplicate fields
    my %count;

    my @lines = path($tagpath)->lines;
    for my $line (@lines) {
        my ($field) = $line =~ qr/^(\S+):/;
        $count{$field} += 1
          if defined $field;
    }

    ok((all { $count{$_} == 1 } keys %count),
        "No duplicate fields in $tagpath");

    my $deb822 = Lintian::Deb822::File->new;

    my @sections = $deb822->read_file($tagpath);
    is(scalar @sections, 1, "Tag in $tagpath has exactly one section");

    my $fields = $sections[0] // {};

    # tag has a name
    my $tagname = $fields->value('Tag');
    BAIL_OUT("Tag described in $tagpath has no name")
      unless length $tagname;

    # tagfile is named $tagname.tag
    is(path($tagpath)->basename,
        "$tagname.tag", "Tagfile for $tagname is named $tagname.tag");

    # mandatory fields
    ok($fields->exists($_), "Field $_ exists in $tagpath")for @mandatory;

    # disallowed fields
    ok(!$fields->exists($_), "Field $_ does not exist in $tagpath")
      for @disallowed;

    my $checkname = $fields->value('Check');

    # tag is associated with a check
    ok(length $checkname, "Tag $tagname is associated with a check");

    ok($profile->get_checkinfo($checkname),
        "Tag $tagname is associated with a valid check");

    if ($fields->value('Name-Spaced') eq 'yes') {
        # encapsulating directory is name of check
        my $subdir = path($tagpath)->parent->relative('tags');
        is($subdir, $checkname,
            "Tag $tagname is in directory named '$checkname'");

    } else {
        # encapsulating directory is first letter of tag's name
        my $parentdir = path($tagpath)->parent->basename;
        my $firstletter = lc(substr($tagname, 0, 1));
        is($parentdir, $firstletter,
            "Tag $tagname is in directory named '$firstletter'");
    }

    ok($fields->value('Renamed-From') !~ m{,},
        "Old tag names for $tagname are not separated by commas");

    my $html_output = Lintian::Output::HTML->new;

    my $taginfo = Lintian::Tag::Info->new;
    $taginfo->load($tagpath);

    my $html_description
      = "<!DOCTYPE html><head><title>$tagname</title></head><body>"
      . $html_output->tag_description($taginfo)
      . '</body>';

    my $utf8_description = encode_utf8($html_description);
    my $tidy_out;
    my $tidy_err;

    my @tidy_command = qw(tidy -quiet);
    run3(\@tidy_command, \$utf8_description, \$tidy_out, \$tidy_err);

    is($tidy_err, EMPTY,
        "No warnings from HTML Tidy for tag description in $tagname");
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

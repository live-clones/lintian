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

use Const::Fast;
use File::Find::Rule;
use IPC::Run3;
use List::SomeUtils qw(true);
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";

use Lintian::Deb822::File;
use Lintian::Output::HTML;
use Lintian::Profile;

const my $EMPTY => q{};
const my $SLASH => q{/};
const my $FIXED_TESTS_PER_FILE => 8;

my @tagpaths = sort File::Find::Rule->file()->name('*.tag')->in('tags');

diag scalar @tagpaths . ' known tags.';

# mandatory fields
my @mandatory = qw(Tag Severity Check Explanation);

# disallowed fields
my @disallowed = qw(Reference References Ref Info Certainty);

# tests per desc
my $perfile = $FIXED_TESTS_PER_FILE + scalar @mandatory + scalar @disallowed;

# set the testing plan
plan tests => 1 + $perfile * scalar @tagpaths;

my $profile = Lintian::Profile->new;
$profile->load(undef, undef, 0);

my @descpaths = sort File::Find::Rule->file()->name('*.desc')->in('tags');
diag "Illegal desc file name $_" for @descpaths;
is(scalar @descpaths, 0, 'No tags have the old *.desc name');

for my $tagpath (@tagpaths) {

    my $contents = path($tagpath)->slurp_utf8;
    my @parts = split(m{\n\n}, $contents);

    # test for duplicate fields
    my $duplicates = 0;

    for my $part (@parts) {
        my %count;

        my @lines = split(/\n/, $part);
        for my $line (@lines) {
            my ($field) = $line =~ qr/^(\S+):/;
            $count{$field} += 1
              if defined $field;
        }

        $duplicates += true { $count{$_} > 1 } keys %count;
    }

    is($duplicates, 0, "No duplicate fields in $tagpath");

    my $deb822 = Lintian::Deb822::File->new;

    my @sections = $deb822->read_file($tagpath);
    ok(@sections >= 1, "Tag in $tagpath has at least one section");

    my $fields = shift @sections;

    # tag has a name
    my $tagname = $fields->value('Tag');
    BAIL_OUT("Tag described in $tagpath has no name")
      unless length $tagname;

    # tagfile is named $tagname.tag
    is(path($tagpath)->basename,
        "$tagname.tag", "Tagfile for $tagname is named $tagname.tag");

    my $checkname = $fields->value('Check');

    # tag is associated with a check
    ok(length $checkname, "Tag $tagname is associated with a check");

    if ($fields->value('Name-Spaced') eq 'yes') {

        $tagname = $checkname . $SLASH . $tagname;

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

    # mandatory fields
    ok($fields->declares($_), "Field $_ exists in $tagpath")for @mandatory;

    # disallowed fields
    ok(!$fields->declares($_), "Field $_ does not exist in $tagpath")
      for @disallowed;

    ok(
        length $profile->check_module_by_name->{$checkname},
        "Tag $tagname is associated with a valid check"
    );

    ok($fields->value('Renamed-From') !~ m{,},
        "Old tag names for $tagname are not separated by commas");

    my $html_output = Lintian::Output::HTML->new;

    my $tag = $profile->get_tag($tagname);
    BAIL_OUT("Tag $tagname was not loaded via profile")
      unless defined $tag;

    my $html_description;
    open(my $fh, '>:utf8_strict', \$html_description)
      or die 'Cannot open scalar';
    select $fh;

    print "<!DOCTYPE html><head><title>$tagname</title></head><body>";
    $html_output->describe_tags([$tag]);
    say '</body>';

    select *STDOUT;
    close $fh;

    print $html_description;

    my $tidy_out;
    my $tidy_err;

    my @tidy_command = qw(tidy -quiet);
    run3(\@tidy_command, \$html_description, \$tidy_out, \$tidy_err);

    is($tidy_err, $EMPTY,
        "No warnings from HTML Tidy for tag description in $tagname");
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

# Copyright © 2020 Felix Lechner
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
use List::Compare;
use List::MoreUtils qw(uniq);
use Path::Tiny;
use Test::More;

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Output::Universal qw(tag_name);

use constant SPACE => q{ };
use constant EMPTY => q{};

my @known_undeclared = qw(
  t/recipes/checks/binaries/binaries-unsafe-open
  t/recipes/checks/changes-file/changelog-file-backport
  t/recipes/checks/debian/changelog/changelog-version-bzr
  t/recipes/checks/debian/copyright/patch-empties-directory
  t/recipes/checks/debian/rules/dh-sequencer/curly-braces
  t/recipes/checks/debian/rules/dh-sequencer/double-quotes
  t/recipes/checks/debian/rules/dh-sequencer/explicit-targets
  t/recipes/checks/debian/rules/dh-sequencer/parentheses
  t/recipes/checks/debian/rules/dh-sequencer/single-quotes
  t/recipes/checks/debian/rules/dh-sequencer/with-comments
  t/recipes/checks/debian/upstream/signing-key/upstream-key-minimal
  t/recipes/checks/debian/upstream/signing-key/upstream-keyring
  t/recipes/checks/emacs/elpa/elpa
  t/recipes/checks/fields/changed-by/changelog-file-backport
  t/recipes/checks/fields/changed-by/changes-bad-ubuntu-distribution
  t/recipes/checks/fields/changed-by/changes-distribution-mismatch
  t/recipes/checks/fields/changed-by/changes-experimental-mismatch
  t/recipes/checks/fields/changed-by/changes-file-bad-section
  t/recipes/checks/fields/changed-by/changes-file-size-checksum-mismatch
  t/recipes/checks/fields/changed-by/changes-files-package-builds-dbg-and-dbgsym-variants
  t/recipes/checks/fields/changed-by/changes-missing-fields
  t/recipes/checks/fields/changed-by/changes-missing-format
  t/recipes/checks/fields/changed-by/changes-unreleased
  t/recipes/checks/fields/changed-by/changes-upload-has-backports-version-number
  t/recipes/checks/fields/changed-by/checksum-count-mismatch
  t/recipes/checks/fields/changed-by/distribution-multiple-bad
  t/recipes/checks/fields/changed-by/watch-file-pgpmode-next
  t/recipes/checks/fields/description/changed-by-localhost
  t/recipes/checks/fields/description/changed-by-malformed
  t/recipes/checks/fields/description/changed-by-no-name
  t/recipes/checks/fields/description/changed-by-root
  t/recipes/checks/fields/description/changed-by-root-email
  t/recipes/checks/fields/description/changelog-file-backport
  t/recipes/checks/fields/description/changes-bad-ubuntu-distribution
  t/recipes/checks/fields/description/changes-distribution-mismatch
  t/recipes/checks/fields/description/changes-experimental-mismatch
  t/recipes/checks/fields/description/changes-file-bad-section
  t/recipes/checks/fields/description/changes-file-size-checksum-mismatch
  t/recipes/checks/fields/description/changes-files-package-builds-dbg-and-dbgsym-variants
  t/recipes/checks/fields/description/changes-missing-format
  t/recipes/checks/fields/description/changes-unreleased
  t/recipes/checks/fields/description/changes-upload-has-backports-version-number
  t/recipes/checks/fields/description/checksum-count-mismatch
  t/recipes/checks/fields/description/distribution-multiple-bad
  t/recipes/checks/fields/description/legacy-foo++
  t/recipes/checks/fields/description/watch-file-pgpmode-next
  t/recipes/checks/fields/distribution/changed-by-localhost
  t/recipes/checks/fields/distribution/changed-by-malformed
  t/recipes/checks/fields/distribution/changed-by-no-name
  t/recipes/checks/fields/distribution/changed-by-root
  t/recipes/checks/fields/distribution/changed-by-root-email
  t/recipes/checks/fields/distribution/changes-file-bad-section
  t/recipes/checks/fields/distribution/changes-file-size-checksum-mismatch
  t/recipes/checks/fields/distribution/changes-files-package-builds-dbg-and-dbgsym-variants
  t/recipes/checks/fields/distribution/changes-missing-fields
  t/recipes/checks/fields/distribution/changes-missing-format
  t/recipes/checks/fields/distribution/checksum-count-mismatch
  t/recipes/checks/fields/distribution/generic-empty
  t/recipes/checks/fields/distribution/legacy-foo++
  t/recipes/checks/fields/distribution/watch-file-pgpmode-next
  t/recipes/checks/fields/format/changed-by-localhost
  t/recipes/checks/fields/format/changed-by-malformed
  t/recipes/checks/fields/format/changed-by-no-name
  t/recipes/checks/fields/format/changed-by-root
  t/recipes/checks/fields/format/changed-by-root-email
  t/recipes/checks/fields/format/changelog-file-backport
  t/recipes/checks/fields/format/changes-bad-ubuntu-distribution
  t/recipes/checks/fields/format/changes-distribution-mismatch
  t/recipes/checks/fields/format/changes-experimental-mismatch
  t/recipes/checks/fields/format/changes-file-bad-section
  t/recipes/checks/fields/format/changes-file-size-checksum-mismatch
  t/recipes/checks/fields/format/changes-files-package-builds-dbg-and-dbgsym-variants
  t/recipes/checks/fields/format/changes-missing-fields
  t/recipes/checks/fields/format/changes-unreleased
  t/recipes/checks/fields/format/changes-upload-has-backports-version-number
  t/recipes/checks/fields/format/checksum-count-mismatch
  t/recipes/checks/fields/format/distribution-multiple-bad
  t/recipes/checks/fields/format/generic-empty
  t/recipes/checks/fields/format/legacy-foo++
  t/recipes/checks/fields/format/watch-file-pgpmode-next
  t/recipes/checks/fields/section/generic-empty
  t/recipes/checks/fields/section/legacy-filenames
  t/recipes/checks/fields/standards-version/generic-empty
  t/recipes/checks/fields/urgency/changed-by-localhost
  t/recipes/checks/fields/urgency/changed-by-malformed
  t/recipes/checks/fields/urgency/changed-by-no-name
  t/recipes/checks/fields/urgency/changed-by-root
  t/recipes/checks/fields/urgency/changed-by-root-email
  t/recipes/checks/fields/urgency/changelog-file-backport
  t/recipes/checks/fields/urgency/changes-bad-ubuntu-distribution
  t/recipes/checks/fields/urgency/changes-distribution-mismatch
  t/recipes/checks/fields/urgency/changes-experimental-mismatch
  t/recipes/checks/fields/urgency/changes-file-bad-section
  t/recipes/checks/fields/urgency/changes-file-size-checksum-mismatch
  t/recipes/checks/fields/urgency/changes-files-package-builds-dbg-and-dbgsym-variants
  t/recipes/checks/fields/urgency/changes-missing-fields
  t/recipes/checks/fields/urgency/changes-missing-format
  t/recipes/checks/fields/urgency/changes-unreleased
  t/recipes/checks/fields/urgency/changes-upload-has-backports-version-number
  t/recipes/checks/fields/urgency/checksum-count-mismatch
  t/recipes/checks/fields/urgency/distribution-multiple-bad
  t/recipes/checks/fields/urgency/legacy-foo++
  t/recipes/checks/fields/urgency/watch-file-pgpmode-next
  t/recipes/checks/fields/version/fields-general-missing
  t/recipes/checks/files/compressed/files-mtime
  t/recipes/checks/files/hierarchy/standard/legacy-libbaz
  t/recipes/checks/mailcap/unquoted-placeholder
  t/recipes/checks/pe/missing-security-features-fp
);

my @descpaths = File::Find::Rule->file()->name('desc')->in('t/recipes/checks');

my @testpaths;
for my $descpath (@descpaths) {

    my $testpath = path($descpath)->parent->parent->stringify;
    my $tagspath = "$testpath/eval/tags";

    push(@testpaths, $testpath)
      if -r $tagspath;
}

# set the testing plan
plan tests => scalar @testpaths + 2;

my @undeclared;
for my $testpath (@testpaths) {

    my $descpath = "$testpath/eval/desc";
    my $tagspath = "$testpath/eval/tags";

    my $testcase = read_config($descpath);
    my @testagainst = uniq split(SPACE, $testcase->{test_against} // EMPTY);

    my @lines = path($tagspath)->lines_utf8({ chomp => 1 });
    my @testfor = uniq map { tag_name($_) } @lines;

    my @combined = (@testfor, @testagainst);

    push(@undeclared, $testpath) unless scalar @combined;

  TODO: {
        local $TODO = "Recipe does not test for or against tags in $testpath"
          unless scalar @combined;

        ok(scalar @combined, "Recipe tests for or against tags in $testpath");
    }
}

my $missing = scalar @undeclared;
my $total = scalar @testpaths;
diag "$missing tests out of $total have no declared diagnostic value.";

diag "Test with unknown purpose: $_" for @undeclared;

my $exceptions = List::Compare->new(\@undeclared, \@known_undeclared);
my @unknown = $exceptions->get_Lonly;
my @solved = $exceptions->get_Ronly;

is(scalar @unknown, 0, 'All tests without a declared purpose are known');
diag "Unknown/missing test: $_" for @unknown;

is(scalar @solved,0,'Solved test should be removed from known undeclared set');
diag "Solved test: $_" for @solved;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

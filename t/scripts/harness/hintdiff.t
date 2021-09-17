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
# MA 02110-1301, USA

use strict;
use warnings;

use Capture::Tiny qw(capture_merged);
use Const::Fast;
use List::Util qw(none);
use Path::Tiny;
use Test::More;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $LINESEP => qr/^/;
const my $WAIT_STATUS_SHIFT => 8;

# the files below were generated from changelog-file-general on Feb 1, 2019

# original file
my $original =<<'EOSTR';
changelog-file-general (source): latest-debian-changelog-entry-without-new-date 
changelog-file-general (binary): possible-missing-colon-in-closes Closes #555555
changelog-file-general (binary): misspelled-closes-bug #666666
changelog-file-general (binary): latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
changelog-file-general (binary): latest-changelog-entry-without-new-date 
changelog-file-general (binary): improbable-bug-number-in-closes 1234
changelog-file-general (binary): epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
changelog-file-general (binary): debian-changelog-line-too-long line 8
changelog-file-general (binary): debian-changelog-line-too-long line 15
changelog-file-general (binary): debian-changelog-file-contains-obsolete-user-emacs-settings 
changelog-file-general (binary): debian-changelog-file-contains-invalid-email-address unknown@unknown
changelog-file-general (binary): changelog-references-temp-security-identifier TEMP-1234567-abcdef
changelog-file-general (binary): changelog-not-compressed-with-max-compression changelog.Debian.gz
changelog-file-general (binary): bad-intended-distribution intended to experimental but uploaded to unstable
EOSTR

# test plan
plan tests => 8;

# different order
my $reordered =<<'EOSTR';
changelog-file-general (binary): changelog-references-temp-security-identifier TEMP-1234567-abcdef
changelog-file-general (binary): changelog-not-compressed-with-max-compression changelog.Debian.gz
changelog-file-general (binary): debian-changelog-line-too-long line 15
changelog-file-general (binary): debian-changelog-file-contains-obsolete-user-emacs-settings 
changelog-file-general (binary): debian-changelog-file-contains-invalid-email-address unknown@unknown
changelog-file-general (binary): bad-intended-distribution intended to experimental but uploaded to unstable
changelog-file-general (binary): possible-missing-colon-in-closes Closes #555555
changelog-file-general (binary): misspelled-closes-bug #666666
changelog-file-general (binary): improbable-bug-number-in-closes 1234
changelog-file-general (binary): epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
changelog-file-general (binary): debian-changelog-line-too-long line 8
changelog-file-general (binary): latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
changelog-file-general (binary): latest-changelog-entry-without-new-date 
changelog-file-general (source): latest-debian-changelog-entry-without-new-date 
EOSTR

ok(hintdiff($original, $reordered) eq $EMPTY, 'Reordered hints on the right');
ok(hintdiff($reordered, $original) eq $EMPTY, 'Reordered hints on the left');

# lines missing
my $missing =<<'EOSTR';
changelog-file-general (source): latest-debian-changelog-entry-without-new-date 
changelog-file-general (binary): possible-missing-colon-in-closes Closes #555555
changelog-file-general (binary): latest-changelog-entry-without-new-date 
changelog-file-general (binary): improbable-bug-number-in-closes 1234
changelog-file-general (binary): epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
changelog-file-general (binary): debian-changelog-line-too-long line 15
changelog-file-general (binary): debian-changelog-file-contains-obsolete-user-emacs-settings 
changelog-file-general (binary): debian-changelog-file-contains-invalid-email-address unknown@unknown
changelog-file-general (binary): changelog-references-temp-security-identifier TEMP-1234567-abcdef
changelog-file-general (binary): bad-intended-distribution intended to experimental but uploaded to unstable
EOSTR

my $missingright =<<'EOSTR';
-changelog-file-general (binary): misspelled-closes-bug #666666
-changelog-file-general (binary): latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
-changelog-file-general (binary): debian-changelog-line-too-long line 8
-changelog-file-general (binary): changelog-not-compressed-with-max-compression changelog.Debian.gz
EOSTR

ok(hintdiff($original, $missing) eq $missingright,
    'Missing hints on the right');
ok(hintdiff($missing, $original) eq complement($missingright),
    'Missing hints on the left');

# lines extra
my $extra =<<'EOSTR';
changelog-file-general (source): latest-debian-changelog-entry-without-new-date 
changelog-file-general (binary): possible-missing-colon-in-closes Closes #555555
changelog-file-general (binary): misspelled-closes-bug #666666
changelog-file-general (binary): latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
changelog-file-general (binary): latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
changelog-file-general (binary): latest-changelog-entry-without-new-date 
changelog-file-general (binary): improbable-bug-number-in-closes 1234
changelog-file-general (binary): epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
changelog-file-general (binary): debian-changelog-line-too-long line 8
changelog-file-general (binary): debian-changelog-line-too-long line 15
changelog-file-general (binary): misspelled-closes-bug #666666
changelog-file-general (binary): debian-changelog-file-contains-obsolete-user-emacs-settings 
changelog-file-general (source): completely-new never seen before
changelog-file-general (binary): debian-changelog-file-contains-invalid-email-address unknown@unknown
changelog-file-general (binary): changelog-references-temp-security-identifier TEMP-1234567-abcdef
changelog-file-general (binary): changelog-not-compressed-with-max-compression changelog.Debian.gz
changelog-file-general (binary): bad-intended-distribution intended to experimental but uploaded to unstable
EOSTR

my $extraright =<<'EOSTR';
+changelog-file-general (source): completely-new never seen before
+changelog-file-general (binary): misspelled-closes-bug #666666
+changelog-file-general (binary): latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
EOSTR

ok(hintdiff($original, $extra) eq $extraright, 'Extra hints on the right');
ok(hintdiff($extra, $original) eq complement($extraright),
    'Extra hints on the left');

# lines different
my $different =<<'EOSTR';
changelog-file-general (source): latest-debian-changelog-entry-without-new-date 
changelog-file-general (binary): possible-missing-semicolon-in-closes Closes #555555
changelog-file-general (binary): misspelled-closes-bug #666666
changelog-file-general (binary): latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
changelog-file-general (binary): latest-changelog-entry-without-new-date 
changelog-file-general (binary): improbable-bug-number-in-closes 1234
changelog-file-general (binary): epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
changelog-file-general (binary): debian-changelog-line-too-long line 9
changelog-file-general (binary): debian-changelog-line-too-long line 15
changelog-file-general (source): debian-changelog-file-contains-obsolete-user-emacs-settings 
changelog-file-general (binary): debian-changelog-file-contains-invalid-irc-address unknown@unknown
changelog-file-general (binary): changelog-references-temp-security-identifier TEMP-1234567-abcdef
changelog-file-general (binary): changelog-not-compressed-with-max-compression changelog.Debian.gz
changelog-file-general (binary): bad-intended-distribution intended to experimental but uploaded to unstable
EOSTR

my $differentright =<<'EOSTR';
-changelog-file-general (binary): possible-missing-colon-in-closes Closes #555555
-changelog-file-general (binary): debian-changelog-line-too-long line 8
-changelog-file-general (binary): debian-changelog-file-contains-obsolete-user-emacs-settings 
-changelog-file-general (binary): debian-changelog-file-contains-invalid-email-address unknown@unknown
+changelog-file-general (source): debian-changelog-file-contains-obsolete-user-emacs-settings 
+changelog-file-general (binary): possible-missing-semicolon-in-closes Closes #555555
+changelog-file-general (binary): debian-changelog-line-too-long line 9
+changelog-file-general (binary): debian-changelog-file-contains-invalid-irc-address unknown@unknown
EOSTR

ok(hintdiff($original, $different) eq $differentright,
    'Different hints on the right');
ok(hintdiff($different, $original) eq complement($differentright),
    'Different hints on the left');

exit;

sub complement {
    my ($diff) = @_;

    return $EMPTY
      unless length $diff;

    my @lines = split($LINESEP, $diff);
    $_ = -$_ for @lines;

    return join($EMPTY, reverse sort @lines);
}

sub hintdiff {
    my ($left_contents, $right_contents) = @_;

    my $left_tiny = Path::Tiny->tempfile;
    my $right_tiny = Path::Tiny->tempfile;

    $left_tiny->spew($left_contents);
    $right_tiny->spew($right_contents);

    my @command = ('hintdiff', $left_tiny->stringify, $right_tiny->stringify);
    my ($diff, $status) = capture_merged { system(@command); };
    $status >>= $WAIT_STATUS_SHIFT;

    die 'Error executing: ' . join($SPACE, @command) . ": $!"
      if none { $_ eq $status } (0, 1);

    return $diff;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

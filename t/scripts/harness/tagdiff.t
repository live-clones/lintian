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
use autodie;

use Capture::Tiny qw(capture_merged);
use List::Util qw(none);
use Path::Tiny;
use Test::More;

use constant LINESEP => qr/^/;
use constant EMPTY => q{};
use constant SPACE => q{ };
use constant NEWLINE => qq{\n};

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

ok(tagdiff($original, $reordered) eq EMPTY, 'Reordered tags on the right');
ok(tagdiff($reordered, $original) eq EMPTY, 'Reordered tags on the left');

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

ok(tagdiff($original, $missing) eq $missingright,'Missing tags on the right');
ok(tagdiff($missing, $original) eq complement($missingright),
    'Missing tags on the left');

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

ok(tagdiff($original, $extra) eq $extraright, 'Extra tags on the right');
ok(tagdiff($extra, $original) eq complement($extraright),
    'Extra tags on the left');

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

ok(tagdiff($original, $different) eq $differentright,
    'Different tags on the right');
ok(tagdiff($different, $original) eq complement($differentright),
    'Different tags on the left');

exit;

sub complement {
    my ($diff) = @_;

    return EMPTY
      unless length $diff;

    my @lines = split(LINESEP, $diff);
    $_ = -$_ for @lines;

    return join(EMPTY, reverse sort @lines);
}

sub tagdiff {
    my ($left, $right) = @_;

    my $leftpath = Path::Tiny->tempfile;
    my $rightpath = Path::Tiny->tempfile;

    $leftpath->spew($left);
    $rightpath->spew($right);

    my @command = ('tagdiff', $leftpath, $rightpath);
    my ($diff, $status) = capture_merged { system(@command); };
    $status = ($status >> 8) & 255;

    die 'Error executing: ' . join(SPACE, @command) . ": $!"
      if none { $_ eq $status } (0, 1);

    return $diff;
}

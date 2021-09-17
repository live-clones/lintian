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

use Path::Tiny;
use Test::More;

# the text below was generated from changelog-file-general on Feb 1, 2019

# expected output
my $expected =<<'EOSTR';
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
plan tests => 1;

# EWI input
my $ewi =<<'EOSTR';
E: changelog-file-general source: latest-debian-changelog-entry-without-new-date
W: changelog-file-general: changelog-not-compressed-with-max-compression changelog.Debian.gz
W: changelog-file-general: debian-changelog-file-contains-obsolete-user-emacs-settings
E: changelog-file-general: debian-changelog-file-contains-invalid-email-address unknown@unknown
E: changelog-file-general: latest-changelog-entry-without-new-date
W: changelog-file-general: latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
E: changelog-file-general: epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
E: changelog-file-general: possible-missing-colon-in-closes Closes #555555
W: changelog-file-general: changelog-references-temp-security-identifier TEMP-1234567-abcdef
X: changelog-file-general: bad-intended-distribution intended to experimental but uploaded to unstable
W: changelog-file-general: misspelled-closes-bug #666666
W: changelog-file-general: improbable-bug-number-in-closes 1234
W: changelog-file-general: debian-changelog-line-too-long line 8
W: changelog-file-general: debian-changelog-line-too-long line 15
EOSTR

ok(
    hintextract('EWI', $ewi) eq $expected,
    'Hints extracted from EWI format matched.'
);

exit;

sub hintextract {
    my ($format, $text) = @_;

    my $outpath = Path::Tiny->tempfile;

    my $inpath = Path::Tiny->tempfile;
    $inpath->spew($text);

    die "Cannot run hintextract: $!"
      if (
        system(
            'hintextract', '-f',$format,
            $inpath->stringify,$outpath->stringify
        ));

    return $outpath->slurp;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

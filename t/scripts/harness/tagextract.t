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
plan tests => 5;

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
    tagextract('EWI', $ewi) eq $expected,
    'Tags extracted from EWI format matched.'
);

# fullewi input
my $fullewi =<<'EOSTR';
E: changelog-file-general source (1:1.0-1) [source]: latest-debian-changelog-entry-without-new-date
W: changelog-file-general binary (1:1.0-1) [all]: changelog-not-compressed-with-max-compression changelog.Debian.gz
W: changelog-file-general binary (1:1.0-1) [all]: debian-changelog-file-contains-obsolete-user-emacs-settings
E: changelog-file-general binary (1:1.0-1) [all]: debian-changelog-file-contains-invalid-email-address unknown@unknown
E: changelog-file-general binary (1:1.0-1) [all]: latest-changelog-entry-without-new-date
W: changelog-file-general binary (1:1.0-1) [all]: latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
E: changelog-file-general binary (1:1.0-1) [all]: epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
E: changelog-file-general binary (1:1.0-1) [all]: possible-missing-colon-in-closes Closes #555555
W: changelog-file-general binary (1:1.0-1) [all]: changelog-references-temp-security-identifier TEMP-1234567-abcdef
X: changelog-file-general binary (1:1.0-1) [all]: bad-intended-distribution intended to experimental but uploaded to unstable
W: changelog-file-general binary (1:1.0-1) [all]: misspelled-closes-bug #666666
W: changelog-file-general binary (1:1.0-1) [all]: improbable-bug-number-in-closes 1234
W: changelog-file-general binary (1:1.0-1) [all]: debian-changelog-line-too-long line 8
W: changelog-file-general binary (1:1.0-1) [all]: debian-changelog-line-too-long line 15
EOSTR

ok(
    tagextract('fullewi', $fullewi) eq $expected,
    'Tags extracted from full format matched.'
);

# letterqualifier input
my $letterqualifier =<<'EOSTR';
E[I!]: changelog-file-general source: latest-debian-changelog-entry-without-new-date
W[N!]: changelog-file-general: changelog-not-compressed-with-max-compression changelog.Debian.gz
W[N!]: changelog-file-general: debian-changelog-file-contains-obsolete-user-emacs-settings
E[I!]: changelog-file-general: debian-changelog-file-contains-invalid-email-address unknown@unknown
E[I!]: changelog-file-general: latest-changelog-entry-without-new-date
W[N!]: changelog-file-general: latest-debian-changelog-entry-reuses-existing-version 1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)
E[S ]: changelog-file-general: epoch-changed-but-upstream-version-did-not-go-backwards 1.0 >= 1.0
E[I ]: changelog-file-general: possible-missing-colon-in-closes Closes #555555
W[N!]: changelog-file-general: changelog-references-temp-security-identifier TEMP-1234567-abcdef
X[N?]: changelog-file-general: bad-intended-distribution intended to experimental but uploaded to unstable
W[N!]: changelog-file-general: misspelled-closes-bug #666666
W[N ]: changelog-file-general: improbable-bug-number-in-closes 1234
W[N!]: changelog-file-general: debian-changelog-line-too-long line 8
W[N!]: changelog-file-general: debian-changelog-line-too-long line 15
EOSTR

ok(
    tagextract('letterqualifier', $letterqualifier) eq $expected,
    'Tags extracted from letterqualifier format matched.'
);

# xml input
my $xml =<<'EOSTR';
<package type="changes" name="changelog-file-general" architecture="source all" version="1:1.0-1">
</package>
<package type="source" name="changelog-file-general" architecture="source" version="1:1.0-1">
<tag severity="important" certainty="certain" name="latest-debian-changelog-entry-without-new-date" />
</package>
<package type="buildinfo" name="changelog-file-general" architecture="all source" version="1:1.0-1">
</package>
<package type="binary" name="changelog-file-general" architecture="all" version="1:1.0-1">
<tag severity="normal" certainty="certain" name="changelog-not-compressed-with-max-compression">changelog.Debian.gz</tag>
<tag severity="normal" certainty="certain" name="debian-changelog-file-contains-obsolete-user-emacs-settings" />
<tag severity="important" certainty="certain" name="debian-changelog-file-contains-invalid-email-address">unknown@unknown</tag>
<tag severity="important" certainty="certain" name="latest-changelog-entry-without-new-date" />
<tag severity="normal" certainty="certain" name="latest-debian-changelog-entry-reuses-existing-version">1:1.0-1 == 1.0-1 (last used: Fri, 01 Feb 2019 12:27:45 -0800)</tag>
<tag severity="serious" certainty="possible" name="epoch-changed-but-upstream-version-did-not-go-backwards">1.0 &gt;= 1.0</tag>
<tag severity="important" certainty="possible" name="possible-missing-colon-in-closes">Closes #555555</tag>
<tag severity="normal" certainty="certain" name="changelog-references-temp-security-identifier">TEMP-1234567-abcdef</tag>
<tag severity="normal" certainty="wild-guess" flags="experimental" name="bad-intended-distribution">intended to experimental but uploaded to unstable</tag
>
<tag severity="normal" certainty="certain" name="misspelled-closes-bug">#666666</tag>
<tag severity="normal" certainty="possible" name="improbable-bug-number-in-closes">1234</tag>
<tag severity="normal" certainty="certain" name="debian-changelog-line-too-long">line 8</tag>
<tag severity="normal" certainty="certain" name="debian-changelog-line-too-long">line 15</tag>
</package>
EOSTR

ok(
    tagextract('xml', $xml) eq $expected,
    'Tags extracted from xml format matched.'
);

# colons input
my $colons =<<'EOSTR';
tag:E:important:certain::changelog-file-general:1\:1.0-1:source:source:latest-debian-changelog-entry-without-new-date::
tag:W:normal:certain::changelog-file-general:1\:1.0-1:all:binary:changelog-not-compressed-with-max-compression:changelog.Debian.gz:
tag:W:normal:certain::changelog-file-general:1\:1.0-1:all:binary:debian-changelog-file-contains-obsolete-user-emacs-settings::
tag:E:important:certain::changelog-file-general:1\:1.0-1:all:binary:debian-changelog-file-contains-invalid-email-address:unknown@unknown:
tag:E:important:certain::changelog-file-general:1\:1.0-1:all:binary:latest-changelog-entry-without-new-date::
tag:W:normal:certain::changelog-file-general:1\:1.0-1:all:binary:latest-debian-changelog-entry-reuses-existing-version:1\:1.0-1 == 1.0-1 (last used\: Fri, 01 Feb 2019 12\:27\:45 -0800):
tag:E:serious:possible::changelog-file-general:1\:1.0-1:all:binary:epoch-changed-but-upstream-version-did-not-go-backwards:1.0 >= 1.0:
tag:E:important:possible::changelog-file-general:1\:1.0-1:all:binary:possible-missing-colon-in-closes:Closes #555555:
tag:W:normal:certain::changelog-file-general:1\:1.0-1:all:binary:changelog-references-temp-security-identifier:TEMP-1234567-abcdef:
tag:I:normal:wild-guess:X:changelog-file-general:1\:1.0-1:all:binary:bad-intended-distribution:intended to experimental but uploaded to unstable:
tag:W:normal:certain::changelog-file-general:1\:1.0-1:all:binary:misspelled-closes-bug:#666666:
tag:W:normal:possible::changelog-file-general:1\:1.0-1:all:binary:improbable-bug-number-in-closes:1234:
tag:W:normal:certain::changelog-file-general:1\:1.0-1:all:binary:debian-changelog-line-too-long:line 8:
tag:W:normal:certain::changelog-file-general:1\:1.0-1:all:binary:debian-changelog-line-too-long:line 15:
EOSTR

ok(
    tagextract('colons', $colons) eq $expected,
    'Tags extracted from colons format matched.'
);

exit;

sub tagextract {
    my ($format, $text) = @_;

    my $outpath = Path::Tiny->tempfile;

    my $inpath = Path::Tiny->tempfile;
    $inpath->spew($text);

    die "Cannot run tagextract: $!"
      if (
        system(
            'tagextract', '-f',$format,
            $inpath->stringify,$outpath->stringify
        ));

    return $outpath->slurp;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

# Copyright © 2018 Felix Lechner
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

BEGIN {
    die('Cannot find LINTIAN_TEST_ROOT')
      unless length $ENV{'LINTIAN_TEST_ROOT'};
}

use File::Basename qw(basename);
use File::stat;
use File::Temp;
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_TEST_ROOT'}/lib";
use Test::Lintian::Run qw(check_result);
use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Templates;

# dummy test name; used in desc and directory name
my $TESTNAME = 'distribution-multiple-bad';

# temporary work directory
my $tempdir = Path::Tiny->tempdir();
my $testpath = $tempdir->child($TESTNAME);
$testpath->mkpath;

# test description
my $desctext =<<EOSTR;
Testname: $TESTNAME
Sequence: 2500
Version: 1.0
Description: Multiple distributions with at least one bad one
Test-For:
 bad-distribution-in-changes-file
 multiple-distributions-in-changes-file
References: Debian Bug #514853
EOSTR
my $descpath = $testpath->child('desc');
$descpath->spew($desctext);

# expected tags
my $expectedtext =<<EOSTR;
E: distribution-multiple-bad changes: backports-upload-has-incorrect-version-number 1.0
E: distribution-multiple-bad changes: bad-distribution-in-changes-file bar
E: distribution-multiple-bad changes: bad-distribution-in-changes-file foo
E: distribution-multiple-bad changes: bad-distribution-in-changes-file foo-backportss
E: distribution-multiple-bad changes: multiple-distributions-in-changes-file stable foo-backportss bar foo
I: distribution-multiple-bad changes: backports-changes-missing
EOSTR
my $expected = $testpath->child('tags');
$expected->spew($expectedtext);

# actual tags with one line missing
my $nomatchtext =<<EOSTR;
E: distribution-multiple-bad changes: backports-upload-has-incorrect-version-number 1.0
E: distribution-multiple-bad changes: bad-distribution-in-changes-file bar
E: distribution-multiple-bad changes: bad-distribution-in-changes-file foo-backportss
E: distribution-multiple-bad changes: multiple-distributions-in-changes-file stable foo-backportss bar foo
I: distribution-multiple-bad changes: backports-changes-missing
EOSTR
my $nomatch = $testpath->child('tags.nomatch');
$nomatch->spew($nomatchtext);

# copy of the expected tags
my $match = $testpath->child('tags.match');
$match->spew($expected->slurp);

# read test defaults
my $defaultspath = 't/defaults/desc';
my $testcase = read_config($defaultspath);

# test plan
plan tests => 2;

# check when tags match
ok(!scalar check_result($testcase, $match, $expected, $expected),
    'Same tags match');

# check tags do not match
ok(scalar check_result($testcase, $nomatch, $expected, $expected),
    'Different tags do not match');

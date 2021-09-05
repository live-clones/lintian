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

BEGIN {
    die('Cannot find LINTIAN_BASE')
      unless length $ENV{'LINTIAN_BASE'};
}

use File::Basename qw(basename);
use File::stat;
use File::Temp;
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";
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
my $desctext =<<"EOSTR";
Testname: $TESTNAME
Sequence: 2500
Version: 1.0
Description: Multiple distributions with at least one bad one
Check:
 changes-file
References: Debian Bug #514853
EOSTR

my $descpath = $testpath->child('desc');
$descpath->spew($desctext);

# expected hints
my $expectedtext =<<'EOSTR';
distribution-multiple-bad (changes): multiple-distributions-in-changes-file stable foo-backportss bar foo
distribution-multiple-bad (changes): bad-distribution-in-changes-file foo-backportss
distribution-multiple-bad (changes): bad-distribution-in-changes-file foo
distribution-multiple-bad (changes): bad-distribution-in-changes-file bar
distribution-multiple-bad (changes): backports-upload-has-incorrect-version-number 1.0
distribution-multiple-bad (changes): backports-changes-missing
EOSTR

my $expected = $testpath->child('hints');
$expected->spew($expectedtext);

# actual hints with one line missing
my $nomatchtext =<<'EOSTR';
distribution-multiple-bad (changes): multiple-distributions-in-changes-file stable foo-backportss bar foo
distribution-multiple-bad (changes): bad-distribution-in-changes-file foo-backportss
distribution-multiple-bad (changes): bad-distribution-in-changes-file bar
distribution-multiple-bad (changes): backports-upload-has-incorrect-version-number 1.0
distribution-multiple-bad (changes): backports-changes-missing
EOSTR

my $nomatch = $testpath->child('hints.nomatch');
$nomatch->spew($nomatchtext);

# copy of the expected hints
my $match = $testpath->child('hints.match');
$match->spew($expected->slurp);

# read test case
my $testcase = read_config($descpath);

# read test defaults
my $defaultspath = 't/defaults/desc';
my $defaults = read_config($defaultspath);

for my $name ($defaults->names) {
    $testcase->store($name, $defaults->value($name))
      unless $testcase->declares($name);
}

# test plan
plan tests => 2;

# check when hints match
ok(!scalar check_result($testcase, $testpath, $expected, $match),
    'Same hints match');

# check hints do not match
ok(scalar check_result($testcase, $testpath, $expected, $nomatch),
    'Different hints do not match');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

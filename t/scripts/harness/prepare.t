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
use File::Temp;
use File::stat;
use IPC::Run3;
use List::Util qw(max);
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";
use Test::Lintian::Prepare qw(prepare);
use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Helper qw(rfc822date);

# dummy test name; used in desc and directory name
my $TESTNAME = 'shared-libs-non-pic-i386';

# temporary work directory
my $tempdir = Path::Tiny->tempdir();

# specification path
my $specpath = $tempdir->child('spec')->child($TESTNAME);
$specpath->mkpath;

# test description
my $desctext =<<"EOSTR";
Testname: $TESTNAME
Version: 1.0-2
Skeleton: upload-native
Test-Architectures: any-amd64 any-i386
Package-Architecture: any
Test-Depends: debhelper (>= 9.20151004~)
Description: Test checks related to non-pic code
Test-For: shlib-with-non-pic-code
Check: shared-libs
EOSTR

my $descpath = $specpath->child('fill-values');
$descpath->spew($desctext);

my $runpath = $tempdir->child('run')->child($TESTNAME);
$runpath->mkpath;

prepare($specpath->stringify, $runpath->stringify, 't');

# read resulting test description
my $testcase = read_config($runpath->child('fill-values')->stringify);

my @testarches = $testcase->trimmed_list('Test-Architectures');

# test plan
plan tests => 20 + scalar @testarches;

is($testcase->unfolded_value('Testname'), $TESTNAME, 'Correct name');

is($testcase->unfolded_value('Version'), '1.0-2', 'Correct version');
is($testcase->unfolded_value('Upstream-Version'),
    '1.0', 'Correct upstream version');

is(
    $testcase->unfolded_value('Test-Architectures'),
    'any-amd64 any-i386',
    'Correct test architectures'
);
isnt($testcase->unfolded_value('Test-Architectures'),
    'any', 'Correct test architectures');
for my $testarch (@testarches) {
    my @command
      = (qw{dpkg-architecture --list-known --match-wildcard}, $testarch);
    my $output;

    run3(\@command, \undef, \$output);
    my @known = grep { length } split(/\n/, $output);

    cmp_ok(scalar @known, '>', 1, "Known test architecture $testarch");
}

is($testcase->unfolded_value('Host-Architecture'),
    $ENV{'DEB_HOST_ARCH'}, 'Correct host architecture');
isnt(
    $testcase->unfolded_value('Host-Architecture'),
    $testcase->unfolded_value('Test-Architectures'),
    'Test and host architectures are different'
);

is($testcase->unfolded_value('Package-Architecture'),
    'any', 'Changed package architecture');
isnt($testcase->unfolded_value('Package-Architecture'),
    'all', 'Not the default package architecture');

is($testcase->unfolded_value('Skeleton'), 'upload-native', 'Correct skeleton');

is(
    $testcase->unfolded_value('Test-Depends'),
    'debhelper (>= 9.20151004~)',
    'Correct test dependencies'
);

is($testcase->unfolded_value('Test-For'),
    'shlib-with-non-pic-code','Correct Test-For');
ok(!$testcase->declares('Test-Against'), 'Correct Test-Against');

is($testcase->unfolded_value('Standards-Version'),
    $ENV{'POLICY_VERSION'}, 'Correct policy version');

is($testcase->unfolded_value('Type'), 'native', 'Test is native');
isnt($testcase->unfolded_value('Type'), 'yes', 'Native type not yes.');

is(
    $testcase->unfolded_value('Dh-Compat-Level'),
    $ENV{'DEFAULT_DEBHELPER_COMPAT'},
    'Default debhelper compat level'
);

is(
    $testcase->unfolded_value('Description'),
    'Test checks related to non-pic code',
    'Correct description'
);
isnt(
    $testcase->unfolded_value('Description'),
    'No Description Available',
    'Not default description'
);

is(
    $testcase->unfolded_value('Author'),
    'Debian Lintian Maintainers <lintian-maint@debian.org>',
    'Default author'
);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

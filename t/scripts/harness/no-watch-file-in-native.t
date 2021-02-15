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
use List::Util qw(max);
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";
use Test::Lintian::Prepare qw(prepare);

# dummy test name; used in desc and directory name
my $TESTNAME = 'test-of-templates-for-native-package';

# temporary work directory
my $tempdir = Path::Tiny->tempdir();

# specification path
my $specpath = $tempdir->child('spec')->child($TESTNAME);
$specpath->mkpath;

# test description
my $desctext =<<"EOSTR";
Testname: $TESTNAME
Version: 1
Skeleton: upload-native
EOSTR

my $descpath = $specpath->child('fill-values');
$descpath->spew($desctext);

my $runpath = $tempdir->child('run')->child($TESTNAME);
$runpath->mkpath;

prepare($specpath->stringify, $runpath->stringify, 't');

# test plan
plan tests => 1;

ok(!-e $runpath->child('debian')->child('watch')->stringify,
    'No watch file present');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

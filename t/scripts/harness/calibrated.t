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
# MA 02110-1301, USA.

# The harness for Lintian's test suite.  For detailed information on
# the test suite layout and naming conventions, see t/tests/README.
# For more information about running tests, see
# doc/tutorial/Lintian/Tutorial/TestSuite.pod
#

use strict;
use warnings;
use v5.10;

use File::Find::Rule;
use Path::Tiny;
use Test::More;

my @descpaths = File::Find::Rule->file->name('desc')->in('t/recipes');

# set the testing plan
plan tests => scalar @descpaths;

for my $descpath (@descpaths) {

    my $testpath = path($descpath)->parent->parent->stringify;
    my $hintspath = "$testpath/eval/hints";
    my $literalpath = "$testpath/eval/literal";

    ok(-r $hintspath || -r $literalpath,
        "Calibrated hints or literal output is readable in $testpath");
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

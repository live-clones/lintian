#!/usr/bin/perl -w
# init.d -- lintian collector script

# Copyright (C) 1998 Richard Braakman
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

use strict;

($#ARGV == 1) or fail("syntax: init.d <pkg> <type>");
my $pkg = shift;
my $type = shift;

-f "fields/package" or fail("init.d invoked in wrong directory");

use lib "$ENV{'LINTIAN_ROOT'}/lib";
use Pipeline;

if (-e "init.d") {
    spawn('rm', '-rf', 'init.d') == 0
	or fail("cannot rm old init.d directory");
}

if (-d "unpacked/etc/init.d") {
    spawn('cp', '-a', 'unpacked/etc/init.d', 'init.d') == 0
	or fail("cannot copy init.d directory");
} else {
    # no etc/init.d
    mkdir("init.d", 0777) or fail("cannot mkdir init.d: $!");
}

exit 0;

# -----------------------------------

sub fail {
    if ($_[0]) {
        print STDERR "internal error: $_[0]\n";
    } elsif ($!) {
        print STDERR "internal error: $!\n";
    } else {
        print STDERR "internal error.\n";
    }
    exit 1;
}

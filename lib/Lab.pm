# Lab -- Perl laboratory functions for lintian
# $Id$

# Copyright (C) 2004 Jeroen van Wolffelaar
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
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

package Lab;
use strict;

use Pipeline;
use File::Temp ( tempdir );

my $LINTIAN_ROOT = $::LINTIAN_ROOT;

# Can also be more precise later on (only verbose with lab actions) but for
# now this will do --Jeroen
my $verbose = $::verbose;
my $debug = $::debug;

my $tempdir = undef;

sub unpack {

	unless (defined $tempdir) {
		$tempdir = tempdir("lintian.XXXXXX",
			TMPDIR => 1, CLEANUP => 1) or
			die("Couldn't create temporary directory for examining
			package(s)");
	}

	my ($type, $package) = @_;

	if ($type eq 'b' || $type eq 'u') {
		spawn("$LINTIAN_ROOT/unpack/unpack-binpkg-l1", $tempdir, $file) == 0
			or die("Failed unpacking $file to level 1");
		spawn("$LINTIAN_ROOT/unpack/unpack-binpkg-l2", $tempdir, $file) == 0
			or die("Failed unpacking $file to level 2");
	} else {
		spawn("$LINTIAN_ROOT/unpack/unpack-srcpkg-l1", $tempdir, $file) == 0
			or die("Failed unpacking $file to level 1");
		spawn("$LINTIAN_ROOT/unpack/unpack-srcpkg-l2", $tempdir, $file) == 0
			or die("Failed unpacking $file to level 2");
	}
}

# Remove is apparantly some reserved name...
sub delete {
	my $LINTIAN_LAB = shift;
	my $lab_mode = shift;

    $SIG{'INT'} = 'DEFAULT';
    $SIG{'QUIT'} = 'DEFAULT';

    print "N: Removing $LINTIAN_LAB ...\n" if $verbose;

    # chdir to root (otherwise, the shell will complain if we happen
    # to sit in the directory we want to delete :)
    chdir('/');

    # does the lab exist?
    unless (-d "$LINTIAN_LAB") {
		# no.
		print STDERR "warning: cannot remove lab in directory $LINTIAN_LAB ! (directory does not exist)\n";
		return;
    }

    # sanity check if $LINTIAN_LAB really points to a lab :)
    unless (-d "$LINTIAN_LAB/binary") {
		# binary/ subdirectory does not exist--empty directory?
		my @t = <$LINTIAN_LAB/*>;
		if ($#t+1 <= 2) {
			# yes, empty directory--skip it
			return;
		} else {
			# non-empty directory that does not look like a lintian lab!
			print STDERR "warning: directory $LINTIAN_LAB does not look like a lab! (please remove it yourself)\n";
			return;
		}
    }

    # looks ok.
    if (spawn('rm', '-rf', '--',
	      "$LINTIAN_LAB/binary",
	      "$LINTIAN_LAB/source",
	      "$LINTIAN_LAB/udeb",
	      "$LINTIAN_LAB/info") != 0) {
		print STDERR "warning: cannot remove lab directory $LINTIAN_LAB (please remove it yourself)\n";
    }

    # dynamic lab?
    if ($lab_mode eq 'temporary') {
		if (rmdir($LINTIAN_LAB) != 1) {
			print STDERR "warning: cannot remove lab directory $LINTIAN_LAB (please remove it yourself)\n";
		}
    }
}

1;

# vim: ts=4 sw=4 noet

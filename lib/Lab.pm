# Lab -- Perl laboratory functions for lintian
# $Id$

# Copyright (C) 1998-2004 Various authors
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

my $LINTIAN_ROOT = $::LINTIAN_ROOT;

# Can also be more precise later on (only verbose with lab actions) but for
# now this will do --Jeroen
my $verbose = $::verbose;
my $debug = $::debug;

sub is_lab {
	my $labdir = shift;

	return -d "$labdir/binary"
		&& -d "$labdir/udeb"
		&& -d "$labdir/source"
		&& -d "$labdir/info";
}

sub setup {
	my $LINTIAN_LAB = shift;
	my $lab_mode = shift;

    print "N: Setting up lab in $LINTIAN_LAB ...\n" if $verbose;

    # create lab directory
    if (not -d "$LINTIAN_LAB" or ($lab_mode eq 'temporary')) {
		# (Note, that the mode 0777 is reduced by the current umask.)
		mkdir($LINTIAN_LAB,0777) or fail("cannot create lab directory $LINTIAN_LAB");
    }

    # create base directories
    if (not -d "$LINTIAN_LAB/binary") {
		mkdir("$LINTIAN_LAB/binary",0777) or fail("cannot create lab directory $LINTIAN_LAB/binary");
    }
    if (not -d "$LINTIAN_LAB/source") {
		mkdir("$LINTIAN_LAB/source",0777) or fail("cannot create lab directory $LINTIAN_LAB/source");
    }
    if (not -d "$LINTIAN_LAB/udeb") {
		mkdir("$LINTIAN_LAB/udeb",0777) or fail("cannot create lab directory $LINTIAN_LAB/udeb");
    }
    if (not -d "$LINTIAN_LAB/info") {
		mkdir("$LINTIAN_LAB/info",0777) or fail("cannot create lab directory $LINTIAN_LAB/info");
    }
	# just create empty files
	_touch("$LINTIAN_LAB/info/binary-packages")
		or fail("cannot create binary package list");
	_touch("$LINTIAN_LAB/info/source-packages")
		or fail("cannot create source package list");
	_touch("$LINTIAN_LAB/info/udeb-packages")
		or fail("cannot create udeb package list");
}

sub populate_with_dist {
    my $LINTIAN_LAB = shift;
    my $LINTIAN_DIST = shift;

	print STDERR "spawning list-binpkg, list-udebpkg and list-srcpkg since LINTIAN_DIST=$LINTIAN_DIST\n" if ($debug >= 2);

	my $v = $verbose ? '-v' : '';

	spawn("$LINTIAN_ROOT/unpack/list-binpkg",
		  "$LINTIAN_LAB/info/binary-packages", $v) == 0
		  or fail("cannot create binary package list");
	spawn("$LINTIAN_ROOT/unpack/list-srcpkg",
		  "$LINTIAN_LAB/info/source-packages", $v) == 0
		  or fail("cannot create source package list");
	spawn("$LINTIAN_ROOT/unpack/list-udebpkg",
		  "$LINTIAN_LAB/info/udeb-packages", $v) == 0
		  or fail("cannot create udeb package list");
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

# create an empty file
# --okay, okay, this is not exactly what `touch' does :-)
sub _touch {
    open(T,">$_[0]") or return 0;
    close(T) or return 0;

    return 1;
}


1;

# vim: ts=4 sw=4 noet

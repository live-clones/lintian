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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lab;
use strict;

use Pipeline;
use Util;
use Lintian::Output qw(:messages);

use File::Temp;

# Quiet "Name "main::LINTIAN_ROOT" used only once"
() = ($main::LINTIAN_ROOT);

my $LINTIAN_ROOT = $main::LINTIAN_ROOT;

sub new {
    my ( $class, $dir, $dist ) = @_;

    my $self = {};
    bless $self, $class;

    $self->setup( $dir, $dist );
    return $self;
}


sub is_lab {
    my ( $self ) = @_;

    return unless $self->{dir};
    return -d "$self->{dir}/binary"
	&& -d "$self->{dir}/udeb"
	&& -d "$self->{dir}/source"
	&& -d "$self->{dir}/info";
}

sub setup {
    my ( $self, $dir, $dist ) = @_;

    if ( $dir ) {
	$self->{mode} = 'static';
	$self->{dir} = $dir;
	$self->{dist} = $dist;
    } else {
	$self->{mode} = 'temporary';

	my $created = 0;
	for (1..10) {
	    $dir = tmpnam();

	    if ($self->setup_force( $dir, $dist )) {
		$created = 1;
		last;
	    }
	}
	unless ($created) {
	    fail("cannot create lab directory $dir");
	}
    }

    return 1;
}

sub setup_static {
    my ( $self ) = @_;

    unless ( $self->{mode} eq 'static' and $self->{dir} ) {
	warning("no laboratory specified (need to define LINTIAN_LAB)");
	return 0;
    }

    return $self->setup_force( $self->{dir}, $self->{dist} );
}


sub setup_force {
    my ( $self, $dir, $dist ) = @_;

    return unless $dir;

    v_msg("Setting up lab in $dir ...");

    # create lab directory
    # (Note, that the mode 0777 is reduced by the current umask.)
    unless (-d $dir && ( $self->{mode} eq 'static' )) {
    	mkdir($dir,0777) or return 0;
    }

    # create base directories
    for my $subdir (qw( binary source udeb info )) {
	my $fulldir = "$dir/$subdir";
	if (not -d $fulldir) {
	    mkdir($fulldir, 0777)
		or fail("cannot create lab directory $fulldir");
	}
    }

    # Just create empty files if they don't already exist.  If they do already
    # exist, we need to keep the old files so that the list-* unpack programs
    # can analyze what changed.
    for my $pkgtype (qw( binary source udeb )) {
	if (not -f "$dir/info/$pkgtype-packages") {
	    _touch("$dir/info/$pkgtype-packages")
		or fail("cannot create $pkgtype package list");
	}
    }

    $self->{dir} = $dir;
    $ENV{'LINTIAN_LAB'} = $dir;
    $self->populate_with_dist( $dist );

    return 1;
}

sub populate_with_dist {
    my ( $self, $dist ) = @_;

    return 0 unless $dist;
    return 0 unless $self->{dir};

    print STDERR "spawning list-binpkg, list-udebpkg and list-srcpkg since LINTIAN_DIST=$dist\n" if ($debug >= 2);

    my $v = $Lintian::Output::GLOBAL->verbose ? '-v' : '';

    spawn("$LINTIAN_ROOT/unpack/list-binpkg",
	  "$self->{dir}/info/binary-packages", $v) == 0
	      or fail("cannot create binary package list");
    spawn("$LINTIAN_ROOT/unpack/list-srcpkg",
	  "$self->{dir}/info/source-packages", $v) == 0
	      or fail("cannot create source package list");
    spawn("$LINTIAN_ROOT/unpack/list-udebpkg",
	  "$self->{dir}/info/udeb-packages", $v) == 0
	      or fail("cannot create udeb package list");

    return 1;
}

sub delete_static {
    my ( $self ) = @_;

    unless ( $self->{mode} eq 'static' and $self->{dir} ) {
	warning("no laboratory specified (need to define LINTIAN_LAB)");
	return 0;
    }

    return $self->delete_force;
}

sub delete {
    my ( $self ) = @_;

    return 1 unless $self->{mode} eq 'temporary';

    return $self->delete_force;
}

# Remove is apparantly some reserved name...
sub delete_force {
    my ( $self ) = @_;

    return 0 unless $self->{dir};

    v_msg("Removing $self->{dir} ...");

    # since we will chdir in a moment, make the path of the lab absolute
    unless ( $self->{dir} =~ m,^/, ) {
	require Cwd;
	$self->{dir} = Cwd::getcwd() . "/$self->{dir}";
    }

    # chdir to root (otherwise, the shell will complain if we happen
    # to sit in the directory we want to delete :)
    chdir('/');

    # does the lab exist?
    unless (-d $self->{dir}) {
		# no.
		warning("cannot remove lab in directory $self->{dir} ! (directory does not exist)");
		return 0;
    }

    # sanity check if $self->{dir} really points to a lab :)
    unless (-d "$self->{dir}/binary") {
		# binary/ subdirectory does not exist--empty directory?
		my @t = glob("$self->{dir}/*");
		if ($#t+1 <= 2) {
			# yes, empty directory--skip it
			return 1;
		} else {
			# non-empty directory that does not look like a lintian lab!
			warning("directory $self->{dir} does not look like a lab! (please remove it yourself)");
			return 0;
		}
    }

    # looks ok.
    if (spawn('rm', '-rf', '--',
	      "$self->{dir}/binary",
	      "$self->{dir}/source",
	      "$self->{dir}/udeb",
	      "$self->{dir}/info") != 0) {
		warning("cannot remove lab directory $self->{dir} (please remove it yourself)");
    }

    # dynamic lab?
    if ($self->{mode} eq 'temporary') {
		if (rmdir($self->{dir}) != 1) {
			warning("cannot remove lab directory $self->{dir} (please remove it yourself)");
		}
    }

    $self->{dir} = "";

    return 1;
}

# create an empty file
# --okay, okay, this is not exactly what `touch' does :-)
sub _touch {
    open(T, '>', $_[0]) or return 0;
    close(T) or return 0;

    return 1;
}


1;

# vim: ts=4 sw=4 noet

# Lab::Package -- Perl laboratory package for lintian

# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
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


package Lab::Package;

=head1 NAME

Lab::Package - A package inside the Lab

=head1 SYNOPSIS

 use Lab;
 
 my $lab = new Lab("dir", "dist");
 my $lpkg = $lab->get_lab_package("name", "version", "type", "path");

 # Unpack the package
 $lpkg->unpack() or die("Could not unpack: $!");
 # Remove package from lab.
 $lpkg->delete_lab_entry();

=head1 DESCRIPTION

Hallo world

=cut

use base qw(Class::Accessor);

use strict;

use Util;
use Lintian::Output qw(:messages); # debug_msg and warning
use Lintian::Command qw();
use Lab qw(:constants); # LAB_FORMAT

=head1 METHODS

=over 4

=item new Lab::Package($lab, $pkg_type, $pkg_name, $pkg_path, $base_dir)

Creates a new Lab::Package inside B<$lab>.  B<$pkg_type> denotes the
(long) type of package (e.g. binary, source, udeb ...) and
B<$pkg_name> is the name of the package.  B<$pkg_path> should be the
absolute path to the packed version of the package (needed during
unpackaging etc.).  B<$base_dir> is the base directory of the package
inside the Lab.

Note: this method should only be used by the Lab.

=cut

## FIXME: relies on $ENV{LINTIAN_ROOT}

sub new{
    my ($class, $lab, $pkg_name, $pkg_version, $pkg_type, $pkg_path, $base_dir) = @_;
    my $self = {};
    bless $self, $class;
    fail("$pkg_path does not exist.") unless( -e $pkg_path );
    $self->{pkg_name} = $pkg_name;
    $self->{pkg_version} = $pkg_version;
    $self->{pkg_path} = $pkg_path;
    $self->{pkg_type} = $pkg_type;
    $self->{lab} = $lab;
    # ask the lab to find the base directory of this package.
    $self->{base_dir} = $base_dir;
    # Figure out our unpack level and such
    $self->_check();
    return $self;
}


=pod

=item $lpkg->lab()

Returns the lab this package is associated with.

=item $lpkg->pkg_name()

Returns the package name.

=item $lpkg->pkg_version();

Returns the version of the package.

=item $lpkg->pkg_path()

Returns the path to the packaged version of actual package.  This path
is used in case the data needs to be extracted from the package.

=item $lpkg->pkg_type()

Returns the type of package (e.g. binary, source, udeb ...)

=item $lpkg->base_dir()

Returns the base directory of this package inside the lab.

=cut

Lab::Package->mk_ro_accessors(qw(lab pkg_name pkg_version pkg_path pkg_type base_dir));

=pod

=item $lpkg->delete_lab_entry()

Removes all unpacked parts of the package in the lab.  Returns a truth
value if successful.

=cut

sub delete_lab_entry {
    my ($self) = @_;
    my $basedir = $self->{base_dir};
    return 1 if( ! -e $basedir);
    debug_msg(1, "Removing package in lab ...");
    unless(delete_dir($basedir)) {
        warning("cannot remove directory $basedir: $!");
        return 0;
    }
    return 1;
}

=pod

=item $lpkg->entry_exists()

Returns a truth value if the lab-entry exists.

=cut

sub entry_exists(){
    my ($self) = @_;
    my $pkg_type = $self->{pkg_type};
    my $base_dir = $self->{base_dir};

    # If we have a positive unpack level, something exists 
    return 1 if ($self->{_unpack_level} > 0);

    # Check if the relevant symlink exists.
    if ($pkg_type eq 'changes'){
	return 1 if ( -l "$base_dir/changes");
    }

    # No unpack level and no symlink => the entry does not
    # exist or it is too broken in its current state.
    return 0;
}

=pod

=item $lpkg->create_entry()

Creates a minimum lab-entry, in which collections and checks
can be run.  Note if it already exists, then this will do
nothing.

=cut

sub create_entry(){
    my ($self) = @_;
    my $pkg_type = $self->{pkg_type};
    my $base_dir = $self->{base_dir};
    my $pkg_path = $self->{pkg_path};
    my $link;
    my $madedir = 0;
    # It already exists.
    return 1 if ($self->entry_exists());
    # We still use the "legacy" unpack for some things.
    return $self->_unpack() unless ($pkg_type ne 'source');

    unless (-d $base_dir) {
	mkdir($base_dir, 0777) or return 0;
	$madedir = 1;
    }
    if ($pkg_type eq 'changes'){
	$link = "$base_dir/changes";
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
	$link = "$base_dir/deb";
    } else {
	fail "create_entry cannot handle $pkg_type";
    }
    unless (symlink($pkg_path, $link)){
	# "undo" the mkdir if the symlink fails.
	rmdir($base_dir) if($madedir);
	return 0;
    }
    # Set the legacy "_unpack_level"
    $self->{_unpack_level} = 1;
    return 1;
}


=pod

=item $lpkg->_unpack()

DEPRECATED

Runs the unpack script for the type of package.  This is
deprecated but remains until all the unpack scripts have
been replaced by coll scripts.

=cut

sub _unpack {
    my ($self) = @_;
    my $level = $self->{_unpack_level};
    my $base_dir = $self->{base_dir};
    my $pkg_type = $self->{pkg_type};
    my $pkg_path = $self->{pkg_path};

    debug_msg(1, sprintf("Current unpack level is %d",$level));

    # Have we already run the unpack script?
    return 1 if $level;

    $self->remove_status_file();

    if ( -d $base_dir ) {
        # We were lied to, there's something already there - clean it up first
        $self->delete_lab_entry() or return 0;
    }

    # create new directory
    debug_msg(1, "Unpacking package ...");
    if ($pkg_type eq 'source') {
	Lintian::Command::Simple::run("$ENV{LINTIAN_ROOT}/unpack/unpack-srcpkg-l1", $base_dir, $pkg_path) == 0
	    or return 0;
    } else {
	fail("_unpack does not know how to handle $pkg_type");
    }

    $self->{_unpack_level} = 1;
    return 1;
}

sub update_status_file{
    my ($self, $lint_version) = @_;
    my @stat;
    my $pkg_path;
    my $fd;
    my $stf = "$self->{base_dir}/.lintian-status";
    # We are not unpacked => no place to put the status file.
    return 0 if($self->{_unpack_level} < 1);
    $pkg_path = $self->{pkg_path};
    unless( @stat = stat($pkg_path)){
	warning("cannot stat file $pkg_path: $!",
		"skipping creation of status file");
	return -1;
    }
    unless(open($fd, '>', $stf)){
	warning("could not create status file $stf for package $self->{pkg_name}: $!");
	return -1;
    }

    print $fd "Lintian-Version: $lint_version\n";
    print $fd "Lab-Format: " . LAB_FORMAT ."\n";
    print $fd "Package: $self->{pkg_name}\n";
    print $fd "Version: $self->{pkg_version}\n";
    print $fd "Type: $self->{pkg_type}\n";
    print $fd "Timestamp: $stat[9]\n";
    close($fd) or return -1;
    return 1;
}

## FIXME - does this really need to be public?
sub remove_status_file{
    my ($self) = @_;
    my $stfile = "$self->{base_dir}/.lintian-status";
    return 1 unless( -e $stfile );
    if(!unlink($stfile)){
	warning("cannot remove status file $stfile: $!");
	return 0;
    }
    return 1;
}

#End of public methods

=pod

=back

=cut

## INTERNAL METHODS ##

# Determines / Guesses the current unpack level - used by the constructor.
sub _check {
    my ($self) = @_;
    my $act_unpack_level = 0;
    my $basedir = $self->{base_dir};
    if( -d $basedir ) {
	my $remove_basedir = 0;
	my $pkg_path = $self->{pkg_path};
	my $data;
	my $pkg_version = $self->{pkg_version};

	# there's a base dir, so we assume that at least
	# one level of unpacking has been done
	$act_unpack_level = 1;

	# lintian status file exists?
	unless (-f "$basedir/.lintian-status") {
	    v_msg("No lintian status file found (removing old directory in lab)");
	    $remove_basedir = 1;
	    goto REMOVE_BASEDIR;
	}

	# read unpack status -- catch any possible errors
	eval { ($data) = read_dpkg_control("$basedir/.lintian-status"); };
	if ($@) {		# error!
	    v_msg($@);
	    $remove_basedir = 1;
	    goto REMOVE_BASEDIR;
	}

	# compatible lintian version?
	if (not exists $data->{'lab-format'} or ($data->{'lab-format'} < LAB_FORMAT)) {
	    v_msg("Lab directory was created by incompatible lintian version");
	    $remove_basedir = 1;
	    goto REMOVE_BASEDIR;
	}

	# version up to date?
	if (not exists $data->{'version'} or ($data->{'version'} ne $pkg_version)) {
	    debug_msg(1, "Removing package in lab (newer version exists) ...");
	    $remove_basedir = 1;
	    goto REMOVE_BASEDIR;
	}

	# file modified?
	my $timestamp;
	my @stat;
	unless (@stat = stat $pkg_path) {
	    warning("cannot stat file $pkg_path: $!");
	} else {
	    $timestamp = $stat[9];
	}
	if ((not defined $timestamp) or (not exists $data->{'timestamp'}) or ($data->{'timestamp'} != $timestamp)) {
	    debug_msg(1, "Removing package in lab (package has been changed) ...");
	    $remove_basedir = 1;
	    goto REMOVE_BASEDIR;
	}

      REMOVE_BASEDIR:
	if ($remove_basedir) {
	    my $pkg_name = $self->{pkg_name};
	    my $lab = $self->{lab};
	    v_msg("Removing $pkg_name");
	    $self->delete_lab_entry() or die("Could not remove $pkg_name from lab.");
	    $act_unpack_level = 0;
	}
    }
    $self->{_unpack_level} = $act_unpack_level;
    return 1;
}

1;


=head1 AUTHOR

Niels Thykier <niels@thykier.net>

=cut

# Local Variables:
# indent-tabs-mode: t
# cperl-indent-level: 4
# End:
# vim: sw=4 ts=8 noet fdm=marker

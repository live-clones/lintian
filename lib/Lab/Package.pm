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
 my $lpkg = $lab->get_lab_package("name", "type", "path");
 
 # reduce unpack level of the package.
 $lpkg->reduce_unpack(1);
 # Remove package from lab.
 $lpkg->delete_lab_entry();

=head1 DESCRIPTION

Hallo world

=cut

use base qw(Class::Accessor);

use strict;

use Util;
use Lintian::Output qw(:messages); # debug_msg and warning

# We use require since Lab also depends on us.
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

=item $lpkg->unpack_level()

Returns the current unpack level.

=cut

Lab::Package->mk_accessors(qw(lab pkg_name pkg_version pkg_path pkg_type base_dir unpack_level));

=pod

=item $lpkg->delete_lab_entry()

Removes all unpacked parts of the package in the lab.  Returns a truth
value if successful.

=cut

sub delete_lab_entry {
    my ($self) = @_;
    my $basedir = $self->{base_dir};
    debug_msg(1, "Removing package in lab ...");
    unless(delete_dir($basedir)) {
        warning("cannot remove directory $basedir: $!");
        return 0;
    }
    return 1;
}

=pod

=item $lpkg->reduce_unpack($new_level)

Reduce the unpack level to B<$new_level>. Returns the unpack level
after the operation has finished. If B<$new_level> is less than 1,
then this will call delete_lab_entry. Returns -1 in case of an
error.

Note if the current level is lower than the new requested level, then
nothing happens and the currnet level is returned instead.

=cut

sub reduce_unpack {
    my ($self, $new_level) = @_;
    my $level = $self->{unpack_level};
    return $level if($level <= $new_level);
    if($new_level < 1){
        return -1 unless($self->delete_lab_entry());
        return 0;
    }

    if($new_level < 2){
        my $base = $self->{base_dir};
        $self->{unpack_level} = $new_level;
        $self->remove_status_file();
	# remove unpacked/ directory
	debug_msg(1, "Decreasing unpack level to 1 (removing files) ...");
	if ( -l "$base/unpacked" ) {
	    delete_dir("$base/".readlink("$base/unpacked"))
		or return -1;
	    delete_dir("$base/unpacked") or return -1;
	} else {
	    delete_dir("$base/unpacked") or return -1;
	}
        return $new_level;
    }

    # This should not happen unless we implement a new unpack level.
    fail("Unhandled reduce_unpack case to $new_level from $level");
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
    $self->{unpack_level} = $act_unpack_level;
    return 1;
}

1;


=head1 AUTHOR

Niels Thykier <niels@thykier.net>

=cut


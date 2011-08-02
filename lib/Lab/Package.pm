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
 my $lpkg = $lab->get_lab_package("name", "version", "arch", "type", "path");

 # create the entry if it does not exist
 $lpkg->create_entry unless $lpkg->entry_exists;

 # Remove package from lab.
 $lpkg->delete_lab_entry();

=head1 DESCRIPTION

Hallo world

=cut

use base qw(Class::Accessor);

use strict;
use warnings;

use Carp qw(croak);
use File::Spec;

use Util;
use Lintian::Output qw(:messages); # debug_msg and warning
use Lintian::Collect;
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
    croak("$pkg_path does not exist.") unless( -e $pkg_path );
    $self->{pkg_name} = $pkg_name;
    $self->{pkg_version} = $pkg_version;
    $self->{pkg_path} = $pkg_path;
    $self->{pkg_type} = $pkg_type;
    $self->{lab} = $lab;
    $self->{info} = undef; # load on demand.
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

=item $lpkg->info()

Returns the L<Lintian::Collect|info> object associated with this entry.

=cut

sub info {
    my ($self) = @_;
    my $info;
    croak 'Cannot load info, extry does not exists' unless $self->entry_exists;
    $info = $self->{info};
    if ( ! defined $info ) {
	$info = Lintian::Collect->new($self->pkg_name, $self->pkg_type, $self->base_dir);
	$self->{info} = $info;
    }
    return $info;
}


=item $lpkg->clear_cache

Clears any caches held; this includes discarding the L<Lintian::Collect|info> object.

=cut

sub clear_cache {
    my ($self) = @_;
    delete $self->{info};
}


=item $lpkg->delete_lab_entry()

Removes all unpacked parts of the package in the lab.  Returns a truth
value if successful.

=cut

sub delete_lab_entry {
    my ($self) = @_;
    my $basedir = $self->{base_dir};
    return 1 if( ! -e $basedir);
    $self->clear_cache;
    unless(delete_dir($basedir)) {
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

    # Check if the relevant symlink exists.
    if ($pkg_type eq 'changes'){
	return 1 if -l "$base_dir/changes";
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
	return 1 if -l "$base_dir/deb";
    } elsif ($pkg_type eq 'source'){
	return 1 if -l "$base_dir/dsc";
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

    unless (-d $base_dir) {
	# if we are in a multi-arch or/and multi-version lab we may
	# need to make more than one dir.  On error we will only kill
	# the "top dir" and that is enough.
	system ('mkdir', '-p', $base_dir) == 0
	    or return 0;
	$madedir = 1;
    }
    if ($pkg_type eq 'changes'){
	$link = "$base_dir/changes";
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
	$link = "$base_dir/deb";
    } elsif ($pkg_type eq 'source'){
	$link = "$base_dir/dsc";
    } else {
	croak "create_entry cannot handle $pkg_type";
    }
    unless (symlink($pkg_path, $link)){
	# "undo" the mkdir if the symlink fails.
	rmdir($base_dir) if($madedir);
	return 0;
    }
    if ($pkg_type eq 'source'){
	# If it is a source package, pull in all the related files
	#  - else unpacked will fail or we would need a separate
	#    collection for the symlinking.
	my $data = get_dsc_info($pkg_path);
	my (undef, $dir, undef) = File::Spec->splitpath($pkg_path);
	for my $fs (split(m/\n/o,$data->{'files'})) {
	    $fs =~ s/^\s*//o;
	    next if $fs eq '';
	    my @t = split(/\s+/o,$fs);
	    next if ($t[2] =~ m,/,o);
	    symlink("$dir/$t[2]", "$base_dir/$t[2]")
		or croak("cannot symlink file $t[2]: $!");
	}
    }
    return 1;
}

# $lpkg->_mark_coll_finished($name, $version)
#
#  Record that the collection $name (at version) has been run on this
#  entry.
#
#  returns a truth value on success; otherwise $! will contain the error
#
#  This is used by frontend/lintian, but probably should not be.
sub _mark_coll_finished {
    my ($self, $collname, $collver) = @_;
    # In the "old days" we would also write the Lintian version and the time
    # stamp in these files, but since we never read them it seems like overkill.
    #  - for the timestamp we could use the mtime of the file anyway
    return touch_file "$self->{base_dir}/.$collname-$collver";
}

# $lpkg->_is_coll_finished($name, $version)
#
#  returns a truth value if a collection with $name at $version has been
#  marked as completed.
#
#  This is used by frontend/lintian, but probably should not be.
sub _is_coll_finished {
    my ($self, $collname, $collver) = @_;
    return -e "$self->{base_dir}/.$collname-$collver";
}

# $lpkg->_clear_coll_status($name)
#
#  Removes all completation status for collection $name.
#
#  Returns a truth value on success; otherwise $! will contain the error
#
#  This is used by frontend/lintian, but probably should not be.
sub _clear_coll_status {
    my ($self, $collname) = @_;
    my $ok = 1;
    my $serr;
    opendir my $d, $self->{base_dir} or return 0;
    foreach my $file (readdir $d) {
	next unless $file =~ m,^\.$collname-\d++$,;
	unless (unlink "$d/$file") {
	    # store the first error
	    next unless $ok;
	    $serr = $!;
	    $ok = 0;
	}
    }
    closedir $d or return 0;
    $! = $serr unless $ok;
    return $ok;
}

sub update_status_file{
    my ($self, $lint_version) = @_;
    my @stat;
    my $pkg_path;
    my $fd;
    my $stf = "$self->{base_dir}/.lintian-status";
    # We are not unpacked => no place to put the status file.
    return 0 unless $self->entry_exists();
    $pkg_path = $self->{pkg_path};
    unless( @stat = stat($pkg_path)){
	return -1;
    }
    unless(open($fd, '>', $stf)){
	return -1;
    }

    print $fd "Lintian-Version: $lint_version\n";
    print $fd 'Lab-Format: ' . LAB_FORMAT ."\n";
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
	return 0;
    }
    return 1;
}

#End of public methods

=pod

=back

=cut

## INTERNAL METHODS ##

# Checks if the existing (if any) entry is compatible,
# if not, it will be removed.
sub _check {
    my ($self) = @_;
    my $basedir = $self->{base_dir};
    if( -d $basedir ) {
	my $remove_basedir = 0;
	my $pkg_path = $self->{pkg_path};
	my $data;
	my $pkg_version = $self->{pkg_version};

	# lintian status file exists?
	unless (-f "$basedir/.lintian-status") {
	    v_msg('No lintian status file found (removing old directory in lab)');
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
	    v_msg('Lab directory was created by incompatible lintian version');
	    $remove_basedir = 1;
	    goto REMOVE_BASEDIR;
	}

	# version up to date?
	if (not exists $data->{'version'} or ($data->{'version'} ne $pkg_version)) {
	    debug_msg(1, 'Removing package in lab (newer version exists) ...');
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
	    debug_msg(1, 'Removing package in lab (package has been changed) ...');
	    $remove_basedir = 1;
	    goto REMOVE_BASEDIR;
	}

      REMOVE_BASEDIR:
	if ($remove_basedir) {
	    my $pkg_name = $self->{pkg_name};
	    my $lab = $self->{lab};
	    v_msg("Removing $pkg_name");
	    $self->delete_lab_entry() or croak("Could not remove outdated/corrupted $pkg_name entry from lab.");
	}
    }
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

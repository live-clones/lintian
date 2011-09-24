# Lintian::Lab::Entry -- Perl laboratory entry for lintian

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


package Lintian::Lab::Entry;

=head1 NAME

Lintian::Lab::Entry - A package inside the Lab

=head1 SYNOPSIS

 use Lintian::Lab;
 
 my $lab = Lintian::Lab->new ("dir", "dist");
 my $lpkg = $lab->get_package ("name", "version", "arch", "type", "path");
 
 # create the entry if it does not exist
 $lpkg->create_entry unless $lpkg->entry_exists;
 
 # Remove package from lab.
 $lpkg->delete_lab_entry;

=head1 DESCRIPTION

... FIXME ?

=head2 METHODS

=over 4

=cut

use base qw(Class::Accessor);

use strict;
use warnings;

use Carp qw(croak);
use File::Spec;

use Lintian::Lab;

use Util qw(delete_dir read_dpkg_control get_dsc_info);

sub new {
    my ($type, $lab, $pkg_name, $pkg_version, $pkg_type, $pkg_path, $base_dir) = @_;
    my $self = {};
    bless $self, $type;
    croak("$pkg_path does not exist.") unless( -e $pkg_path );
    $self->{pkg_name}    = $pkg_name;
    $self->{pkg_version} = $pkg_version;
    $self->{pkg_path}    = $pkg_path;
    $self->{pkg_type}    = $pkg_type;
    $self->{lab}         = $lab;
    $self->{info}        = undef; # load on demand.
    $self->{coll}        = {};
    # ask the lab to find the base directory of this package.
    $self->{base_dir} = $base_dir;

    $self->_init();
    return $self;
}

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

Lintian::Lab::Entry->mk_ro_accessors(qw(pkg_name pkg_version pkg_path pkg_type base_dir));

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
    $self->{lab}->_entry_removed ($self);
    return 1;
}

=item $lpkg->entry_exists()

Returns a truth value if the lab-entry exists.

=cut

sub entry_exists {
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

=item $lpkg->create_entry()

Creates a minimum lab-entry, in which collections and checks
can be run.  Note if it already exists, then this will do
nothing.

=cut

sub create_entry {
    my ($self) = @_;
    my $pkg_type = $self->{pkg_type};
    my $base_dir = $self->{base_dir};
    my $pkg_path = $self->{pkg_path};
    my $lab      = $self->{lab};
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
    $lab->_entry_created ($self);
    return 1;
}

=item $lpkg->coll_version ($coll)

Returns the version of the collection named $coll, if that
$coll has been marked as finished.

Returns the empty string if $coll has not been marked as finished.

Note: The version can be 0.

=cut

sub coll_version {
    my ($self, $coll) = @_;
    return $self->{coll}->{$coll}//'';
}

=item $lpkg->is_coll_finished ($coll, $version)

Returns a truth value if the collection $coll has been completed as
its version is at least $version.  The versions are assumed to be
integers (the comparision is done with ">=").

This returns 0 if the collection $coll has not been marked as
finished.

=cut

sub is_coll_finished {
    my ($self, $coll, $version) = @_;
    my $c = $self->coll_version ($coll);
    return 0 if $c eq '';
    return $c >= $version;
}

# $lpkg->_mark_coll_finished ($coll, $version)
#
# non-public method to mark a collection as complete
sub _mark_coll_finished {
    my ($self, $coll, $version) = @_;
    $self->{coll}->{$coll} = $version;
    return 1;
}

# $lpkg->_clear_coll_status ($coll)
#
# Removes the notion that $coll has been fixed.
sub _clear_coll_status {
    my ($self, $coll) = @_;
    delete $self->{coll}->{$coll};
    return 1;
}

=item $lpkg->update_status_file ()

Flushes the cached changes of which collections have been completed.

This should also be called for new entries to create the status file.

=cut

sub update_status_file {
    my ($self) = @_;
    my $file;
    my @sc;

    return 0 unless $self->entry_exists;

    $file = $self->base_dir () . '/.lintian-status';
    open my $sfd, '>', $file or return 0;
    print $sfd 'Lab-Format: ' . Lintian::Lab::LAB_FORMAT . "\n";

    @sc = sort keys %{ $self->{coll} };
    print $sfd "Collections: \n";
    print $sfd ' ' . join (",\n ", map { "$_=$self->{coll}->{$_}" } @sc);
    print $sfd "\n\n";
    close $sfd or return 0;
    return 1;
}

sub _init {
    my ($self) = @_;
    my $base_dir = $self->base_dir;
    my @data;
    my $head;
    my $coll;
    return unless $self->entry_exists;
    return unless -e "$base_dir/.lintian-status";
    @data = read_dpkg_control ("$base_dir/.lintian-status");
    $head = $data[0];

    # Check that we know the format.
    return unless (Lintian::Lab::LAB_FORMAT eq $head->{'lab-format'}//'');

    $coll = $head->{'collections'}//'';
    $coll =~ s/\n/ /go;
    foreach my $c (split m/\s*,\s*+/o, $coll) {
        my ($cname, $cver) = split m/\s*=\s*/, $c;
        $self->{coll}->{$cname} = $cver;
    }
}

=back

=head1 AUTHOR

Niels Thykier <niels@thykier.net>

=cut

1;


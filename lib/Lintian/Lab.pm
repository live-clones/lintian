# Lintian::Lab -- Perl laboratory functions for lintian

# Copyright (C) 2011 Niels Thykier
#   - Based on the work of "Various authors"  (Copyright 1998-2004)
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

package Lintian::Lab;

use strict;
use warnings;

use base qw(Class::Accessor Exporter);

use Carp qw(croak);
use Cwd();

use File::Temp qw(tempdir); # For temporary labs

use Scalar::Util qw(blessed);


use constant {
# Lab format Version Number increased whenever incompatible changes
# are done to the lab so that all packages are re-unpacked
    LAB_FORMAT      => 10.1,
# Constants to avoid semantic errors due to typos in the $lab->{'mode'}
# field values.
    LAB_MODE_STATIC => 'static',
    LAB_MODE_TEMP   => 'temporary',
};

# A private table of suported types.
my %SUPPORTED_TYPES = (
    'binary'  => 1,
    'changes' => 1,
    'source'  => 1,
    'udeb'    => 1,
);

# Export now due to cicular depends between Lab and Lab::Package.
our (@EXPORT, @EXPORT_OK, %EXPORT_TAGS);

BEGIN {
    @EXPORT = ();
    %EXPORT_TAGS = (
        constants => [qw(LAB_FORMAT)],
    );
    @EXPORT_OK = (
        @{ $EXPORT_TAGS{constants} }
    );
};

use Util qw(delete_dir); # Used by $lab->remove_lab

=head1 NAME

Lintian::Lab -- Interface to the Lintian Lab

=head1 SYNOPSIS

 use Lintian::Lab;
 
 # Static lab
 my $lab = Lintian::Lab->new ('/var/lib/lintian/static-lab');

 if (!$lab->lab_exists) {
     $lab->create_lab;
 }
 $lab->open_lab;
 
 # Fetch a package from the lab
 my $pkg = $lab->get_package ('lintian', 'binary', '2.5.4', 'all');
 
 #FIXME: Add more to the synopsis here
 
 $lab->close;

=head2 Methods

=over 4

=item Lintian::Lab->new([$dir])

Creates a new Lab instance.  If C<$dir> is passed it will be used as
the path to the lab and the lab will be in static mode.  Otherwise the
lab will be in temporary mode and will point to a temporary directory.

=cut


sub new {
    my ($class, $dir) = @_;
    my $absdir;
    my $mode = LAB_MODE_TEMP;
    if ($dir) {
        $absdir = Cwd::abs_path($dir);
        croak ("Cannot resolve $dir: $!") unless $absdir;
        $mode = LAB_MODE_STATIC;
    } else {
        $absdir = ''; #Ensure it is defined.
    }
    my $self = {
        # Must be absolute (frontend/lintian depends on it)
        #  - also $self->dir promises this
        #  - it may be the empty string (see $self->dir)
        'dir'         => $absdir,
        'state'       => {},
        'state-table' => {},
        'mode'        => $mode,
        'is_open'     => 0,
        'keep-lab'    => 0,
    };
    bless $self, $class;
    $self->_init ($dir);
    return $self;
}

=item $lab->dir

Returns the absolute path to the base of the lab.

Note: This may return the empty string if either the lab has been
deleted or this is a temporary lab that has not been created yet.
In the latter case, $lab->create_lab should be run to get a
non-empty value from this method.

=item $lab->is_open

Returns a truth value if this lab is open.

Note: This does not imply that the underlying does not exists.

=cut

Lintian::Lab->mk_ro_accessors (qw(dir is_open));

=item $lab->lab_exists

Returns a truth value if B<$lab> points to an existing lab.

Note: This does not imply whether or not the lab is open.

=cut

sub lab_exists {
    my ( $self ) = @_;
    my $dir = $self->dir;
    return unless $dir;
    # New style lab?
    return 1 if -d "$dir/info" && -d "$dir/pool";
    # 10-style lab?
    return -d "$dir/binary"
	&& -d "$dir/udeb"
	&& -d "$dir/source"
	&& -d "$dir/info";
}

=item $lab->get_package ($pkg_name, $pkg_type, $pkg_version, $pkg_arch), $lab->get_package ($proc)

Fetches an existing package from the lab.

First argument can be a L<Lintian::Processable|proccessable>.  In that
case all other arguments are ignored.

=cut

sub get_package {
    my ($self, $pkg, $pkg_type, $pkg_version, $pkg_arch) = @_;
    my $pkg_name;
    my $path;
    my $lindex;
    my $table;
    my $result;

    if (blessed $pkg && $pkg->isa ('Lintian::Processable')) {
        my $proc = $pkg_name;
        $pkg_name = $proc->pkg_name;
        $pkg_type = $proc->pkg_type;
        $pkg_version = $proc->pkg_version;
        $pkg_arch = $proc->pkg_arch;
    } else {
        $pkg_name = $pkg;
        croak ("Package name and type must be defined") unless $pkg_name && $pkg_type;
    }

    $lindex = $self->_get_lab_index($pkg_type);
    $table = $lindex->{$pkg_name};
    return unless $table; # No package with this name of this type?

    # TODO allow version to be blank to mean "any" ?
    return unless defined $pkg_version; # Allow version "0"

    $result = $table->{$pkg_version};
    return unless $result; # No package with that version?

    # Source packages have no "architecture", so we are done here.
    return $result if $pkg_type eq 'source';

    # TODO allow version to be blank to mean "any" ?
    return unless $pkg_arch;

    return $result->{$pkg_arch};
}

# Returns the index of packages in the lab of a given type (of packages).
#
# Unlike $lab->_load_lab_index, this uses the cache'd version if it is
# available.
sub _get_lab_index {
    my ($self, $pkg_type) = @_;
    croak ("Unknown package type $pkg_type") unless $SUPPORTED_TYPES{$pkg_type};
    # Fetch (or load) the index of that type
    return $self->{'state-table'}->{$pkg_type} // $self->_load_lab_index($pkg_type);
}

# Unconditionally (Re-)loads the index of packages in the lab of a
# given type (of packages).
#
# $lab->_get_lab_index is generally faster since it uses the cache if
# available.
sub _load_lab_index {
    my ($self, $pkg_type) = @_;
    my $dir = $self->dir;
    my $pf = Lintian::Internal::PackageList->new ($pkg_type);
    my $lif = "$dir/info/${pkg_type}-packages";
    my $lindex = {};
    $pf->read_list ($lif);
    # FIXME: make a dedicated object for this structure ?
    #  - Maybe extend L::I::PackageList
    foreach my $pd ( $pf->get_all ) {
        my $pkg_name;
        my $pkg_version = $pd->{'version'};
        my $pkg_arch;
        if ($pkg_type ne 'source' && $pkg_type ne 'changes') {
            $pkg_name = $pd->{'source'};
        } else {
            $pkg_name = $pd->{'package'};
        }
        if ($pkg_type eq 'source') {
            $lindex->{$pkg_name}->{$pkg_version} = $pd;
        } else {
            $pkg_arch = $pd->{'architecture'};
            $lindex->{$pkg_name}->{$pkg_version}->{$pkg_arch} = $pd;
        }
    }
    $self->{'state'}->{$pkg_type} = $pf;
    $self->{'state-table'}->{$pkg_type} = $lindex;
    return $lindex;
}

# Given the package meta data (name, type, version, arch) return the
# path to it in the Lab.  Path returned will be absolute.
sub _pool_path {
    my ($self, $pkg_name, $pkg_type, $pkg_version, $pkg_arch) = @_;
    my $path = $self->dir;
    my $p;
    if ($pkg_name =~ m/^lib/o) {
        $p = substr $pkg_name, 0, 4;
    } else {
        $p = substr $pkg_name, 0, 1;
    }
    $path .= "/$p/$pkg_name/${pkg_name}_${pkg_version}";
    $path .= "_${pkg_arch}" unless $pkg_type eq 'source';
    $path .= "_${pkg_type}";
    return $path;
}

=item $lab->create_lab ([$opts])

Creates a new lab.  It will create $self->dir if it does not
exists.  It will also create a basic lab empty lab.  If this is
a temporary lab, this method will also setup the temporary dir
for the lab.

B<$opts> (if present) is a hashref containing options.  Currently only
"keep-lab" is recognized.  If "keep-lab" points to a truth value the
temporary directory will I<not> be removed by closing the lab (nor
exiting the application).  However, explicitly calling
$self->remove_lab will remove the lab.

Note: This will not create parent directories of $self->dir and will
croak if these does not exists.

=cut

sub create_lab {
    my ($self, $opts) = @_;
    my $dir = $self->dir;
    my $mid = 0;
    $opts = {} unless $opts;
    if ( !$dir or $self->{'mode'} eq LAB_MODE_TEMP) {
        if ($self->{'mode'} eq LAB_MODE_TEMP) {
            my $keep = $opts->{'keep-lab'}//0;
            my $topts = { CLEAN => !$keep, TMPDIR => 1 };
            my $t = tempdir ('temp-lintian-lab-XXXXXX', $topts);
            $dir = Cwd::abs_path ($t);
            croak ("Could not resolve $dir: $!") unless $dir;
            $self->{'dir'} = $dir;
            $self->{'keep-lab'} = $keep;
        } else {
            # This should not be possible - but then again,
            # code should not have any bugs either...
            croak ('Lab path may not be empty for a static lab');
        }
    }
    # Create the top dir if needed - note due to Lintian::Lab->new
    # and the above tempdir creation code, we know that $dir is
    # absolute.
    croak ("Cannot create $dir: $!") unless -d $dir or mkdir $dir;

    # Top dir exists, time to create the minimal directories.
    unless (-d "$dir/info") {
        mkdir "$dir/info" or croak ("mkdir $dir/info: $!");
        $mid = 1; # remember we created the info dir
    }

    unless (-d "$dir/pool") {
        unless (mkdir "$dir/pool") {
            my $err = $!; # store the error
            # Remove the info dir if we made it.  This attempts to
            # prevent a semi-created lab that the API cannot remove
            # again.
            #
            # ignore the error (if any) - we can only do so much
            rmdir "$dir/info" if $mid;
            $! = $err;
            croak ("mkdir $dir/pool: $!");
        }
    }
    # Okay - $dir/info and $dir/pool exists... The subdirs in
    # $dir/pool will be created as needed.

    # TODO: populate $dir/info ?  L::I::PackageList probably
    # does not care... ( see L::I::PackageList::read_list )
    return 1;
}

=item $lab->open_lab

Opens the lab and reads the contents into caches.  If the Lab is
temporary this will create a temporary dir to store the contents of
the lab.

This will croak if the lab is already open.  It may also croak for
the same reasons as $lab->create_lab if this is a temporary lab.

Note: for static labs, $lab->dir must point to an existing consistent
lab or this will croak.  To open a new lab, please use
$lab->create_lab.

Note: It is not possible to pass options to the creation of the
temporary lab.  If special options are required, please use
$lab->create_lab.

=cut

sub open_lab {
    my ($self) = @_;
    croak ('Lab is already open') if $self->is_open();
    if ($self->{'mode'} eq LAB_MODE_TEMP) {
        $self->create_lab() unless $self->lab_exists();
    } else {
        my $dir = $self->dir;
        unless ($self->lab_exists()) {
            my $msg = "Open Lab failed: ";
            croak ("$msg: $dir does not exists") unless -e $dir;
            croak ("$msg: $dir is not a lab or the lab is corrupt");
        }

    }
    $self->{'is_open'} = 1;
    return 1;
}

=item $lab->close_lab

Close the lab - all state caches will be flushed to the disk and the
lab can no longer be used.  All references to entries in the lab
should be considered invalid.

Note: if the lab is a temporary one, this will be deleted unless it
was created with "keep-lab" (see $lab->create_lab).

=cut

sub close_lab {
    my ($self) = @_;
    return unless $self->lab_exists();
    if ($self->{'mode'} eq LAB_MODE_TEMP && !$self->{'keep-lab'}) {
        # Temporary lab (without "keep-lab" property)
        $self->remove_lab();
    } else {
        my $dir = $self->dir;
        while ( my ($pkg_type, $plist) = (each %{ $self->{'state'} }) ) {
            # write_list croaks on error, so no need for "or croak/die"
            $plist->write_list ("$dir/info/${pkg_type}-packages")  if $plist->dirty;
        }
    }
    $self->{'state'} = {};
    $self->{'is_open'} = 0;
    return 1;
}

=item $lab->remove_lab

Removes the lab and everything in it.  Any reference to an entry
returned from this lab will immediately become invalid.

If this is a temporary lab, the lab root dir (as returned $lab->dir)
will be removed as well on success.  Otherwise the lab root dir will
not be removed by this call.

On success, this will return a truth value.  If the lab is a temporary
lab, the directory path will be set to the empty string (that is,
$lab->dir will return '').

On error, this method will croak.

If the lab has already been removed (or does not exists), this will
return a truth value.

=cut

sub remove_lab {
    my ($self) = @_;
    my $dir = $self->dir;
    my @subdirs = ();
    my $empty = 0;

    return 1 unless $dir && -d $dir;

    # sanity check if $self->{dir} really points to a lab :)
    unless (-d "$dir/info") {
        # info/ subdirectory does not exist--empty directory?
        my @t = glob("$dir/*");
        if ($#t+1 <= 2) {
            # yes, empty directory--skip it
            $empty = 1;
        } else {
            # non-empty directory that does not look like a lintian lab!
            croak ("$dir: Does not look like a lab");
        }
    }

    unless ($empty) {
        # looks ok.
        if ( -d "$dir/pool") {
            # New lab style
            @subdirs = qw/pool info/;
        } else {
            # 10-style Lab
            @subdirs = qw/binary source udeb info/;
            push @subdirs, 'changes' if -d "$dir/changes";
        }
        unless (delete_dir( map { "$dir/$_" } @subdirs )) {
            croak ("delete_dir (\$contents): $!");
        }
    }

    # dynamic lab?
    if ($self->{'mode'} eq LAB_MODE_TEMP) {
        rmdir $dir or croak ("rmdir $dir: $!");
        $self->{'dir'} = '';
    }

    $self->{'is_open'} = 0;
    return 1;
}

# initialize the instance
#
# May be overriden by a sub-class.
#
# $self->dir may be the empty string if this is a temporary lab.
sub _init {
    my ($self) = @_;
}

sub _entry_removed {
    my ($self, $entry) = @_;
    my $pkg_name    = $entry->pkg_name;
    my $pkg_type    = $entry->pkg_type;

    my $pf = $self->{'state'};
    $pf->delete ($pkg_name);
}

sub _entry_created {
    my ($self, $entry) = @_;
    my $pkg_name    = $entry->pkg_name;
    my $pkg_type    = $entry->pkg_type;

    croak ("Not implemented");

#    my %data = (
#        'source'  => undef,
#    );
#    my $pf = $self->{'state'};
#    $pf->set ($pkg_name, \%data);

}

=back

=head1 AUTHOR

Niels Thykier <niels@thykier.net>

Based on the work of various others.

=cut

1;


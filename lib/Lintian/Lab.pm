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
    LAB_FORMAT      => 11,
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

use Lintian::Collect;
use Lintian::Lab::Entry;
use Lintian::Lab::Manifest;
use Lintian::Util qw(delete_dir get_dsc_info);

=encoding utf8

=head1 NAME

Lintian::Lab -- Interface to the Lintian Lab

=head1 SYNOPSIS

 use Lintian::Lab;
 
 # Static lab
 my $lab = Lintian::Lab->new ('/var/lib/lintian/static-lab');

 if (!$lab->exists) {
     $lab->create;
 }
 $lab->open;
 
 # Fetch a package from the lab
 my $lpkg = $lab->get_package ('lintian', 'binary', '2.5.4', 'all');
 
 my $visitor = sub {
     my ($lpkg, $pkg_name, $pkg_ver, $pkg_arch) = @_;
     # do stuff with that entry
 };
 $lab->visit_packages ($visitor, 'source');
 
 $lab->close;

=head1 DESCRIPTION

This module provides an abstraction from "How and where" packages are
placed.  It handles creation and deletion of the Lintian Lab itself as
well as providing access to the entries.

=head1 CLASS METHODS

=over 4

=item new ([DIR])

Creates a new Lab instance.  If DIR is passed it will be used as
the path to the lab and the lab will be in static mode.  Otherwise the
lab will be in temporary mode and will point to a temporary directory.

=cut

sub new {
    my ($class, $dir) = @_;
    my $absdir;
    my $mode = LAB_MODE_TEMP;
    my $dok = 1;
    if ($dir) {
        $mode = LAB_MODE_STATIC;
        $absdir = Cwd::abs_path ($dir);
        if (!$absdir) {
            if ($dir =~ m,^/,o) {
                $absdir = $dir;
            } else {
                $absdir = Cwd::cwd . '/' . $dir;
            }
            $dok = 0;
        }
    } else {
        $absdir = ''; #Ensure it is defined.
    }
    my $self = {
        # Must be absolute (frontend/lintian depends on it)
        #  - also $self->dir promises this
        #  - it may be the empty string (see $self->dir)
        'dir'         => $absdir,
        'state'       => {},
        'mode'        => $mode,
        'is_open'     => 0,
        'keep-lab'    => 0,
        'lab-info'    => {},
    };
    $self->{'_correct_dir'} = 1 unless $dok;
    bless $self, $class;
    $self->_init ($dir);
    return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item dir

Returns the absolute path to the base of the lab.

Note: This may return the empty string if either the lab has been
deleted or this is a temporary lab that has not been created yet.  In
the latter case, L</create> or L</open> should be run to get a
non-empty value from this method.

=item is_open

Returns a truth value if this lab is open.

Note: If the lab is open, it also exists.  However, if the lab is
closed then the lab may or may not exist (see L</exists>).

=cut

Lintian::Lab->mk_ro_accessors (qw(dir is_open));

=item exists

Returns a truth value if the instance points to an existing lab.

Note: This never implies that the lab is open.  Though it may imply
the lab is closed (see L</is_open>).

=cut

sub exists {
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

=item get_package (NAME, TYPE[, EXTRA]), get_package (PROC)

Fetches an existing package from the lab.

The first argument can be a L<processable|Lintian::Processable>.  In that
case all other arguments are ignored.

If the first calling convention is used then this method will search
for an existing package.  The EXTRA argument can be used to narrow
the search or even to add a new entry.

EXTRA consists of (in order):

=over 4

=item * version

=item * arch (ignored if TYPE is "source")

=back

If version or arch is omitted (or if it is undef) then that search
parameter is consider a wildcard for "any".  Example:

 # Returns all eclipse-platform packages with architecture i386 regardless
 # of their version (if any)
 @ps  = $lab->get_package ('eclipse-platform', 'binary', undef, 'i386');
 # Returns all eclipse-platform packages with version 3.5.2-11 regardless
 # of their architecture (if any)
 @ps  = $lab->get_package ('eclipse-platform', 'binary', '3.5.2-11');
 # Return the eclipse-platform package with version 3.5.2-11 and architecture
 # i386 (or undef)
 $pkg = $lab->get_package ('eclipse-platform', 'binary', '3.5.2-11', 'i386');


In list context, this returns a list of matches.  In scalar context
this returns the first match (if any).  Note there is no guaranteed
order (e.g. the returned list is not ordered).

If the second calling convention is used, then this method will search
for an entry matching the the processable passed.  If such an entry
does not exists, an new "non-existing" L<entry|Lintian::Lab::Entry>
will be returned.  This entry can be created by using the
L<create|Lintian::Lab::Entry/create> method on the entry.

=cut

sub get_package {
    my ($self, $pkg, $pkg_type, $pkg_version, $pkg_arch) = @_;
    my $pkg_name;
    my $pkg_path;
    my @entries;
    my $index;
    my $proc;

    croak 'Lab is not open' unless $self->is_open;

    # TODO: Cache and check for existing entries to avoid passing out
    # the same entry twice with different instances.  Problem being
    # circular references (and weaken may be un-available)

    if (blessed $pkg && $pkg->isa ('Lintian::Processable')) {
        $pkg_name = $pkg->pkg_name;
        $pkg_type = $pkg->pkg_type;
        $pkg_version = $pkg->pkg_version;
        $pkg_arch = $pkg->pkg_arch;
        $pkg_path = $pkg->pkg_path;
        $proc = $pkg;
    } else {
        $pkg_name = $pkg;
        croak "Package name and type must be defined" unless $pkg_name && $pkg_type;
    }

    $index = $self->_get_lab_index ($pkg_type);

    if (defined $pkg_version && (defined $pkg_arch || $pkg_type eq 'source')) {
        # We know everything - just do a regular look up
        my $dir;
        my @keys = ($pkg_name, $pkg_version);
        my $e;
        my ($pkg_src, $pkg_src_version);
        push @keys, $pkg_arch if $pkg_type ne 'source';
        if ($proc) {
            $pkg_src = $proc->pkg_src;
            $pkg_src_version = $proc->pkg_src_version;
        } else {
            $e = $index->get (@keys);
            return unless $e;
            $pkg_src = $e->{'source'};
            $pkg_src_version = $e->{'source-version'};
        }
        $dir = $self->_pool_path ($pkg_src, $pkg_type, $pkg_name, $pkg_version, $pkg_arch);
        push @entries, Lintian::Lab::Entry->_new ($self, $pkg_name, $pkg_version, $pkg_arch, $pkg_type, $pkg_path, $pkg_src, $pkg_src_version, $dir);
    } else {
        # clear $pkg_arch if it is a source package - it simplifies
        # the search code below
        undef $pkg_arch if $pkg_type eq 'source';
        my $searcher = sub {
            my ($entry, @keys) = @_;
            my ($n, $v, $a) = @keys;
            my $dir;
            # We do not have to check version - if we have a specific
            # version, only entries with that version will be visited.
            return if defined $pkg_arch && $a ne $pkg_arch;
            $dir = $self->_pool_path ($entry->{'source'}, $pkg_type, $pkg_name, $v, $a);
            push @entries,  Lintian::Lab::Entry->new_from_metadata ($pkg_type, $entry, $self, $dir);
        };
        my @sk = ($pkg_name);
        push @sk, $pkg_version if defined $pkg_version;
        $index->visit_all ($searcher, @sk);
    }

    return wantarray ? @entries : $entries[0];
}

=item visit_packages (VISITOR[, TYPE])

Passes each lab entry to VISITOR.  If TYPE is passed, then only
entries of that type are passed.

VISITOR is given a reference to the L<entry|Lintian::Lab::Entry>,
the package name, the package version and the package architecture
(may be undef for source packages).

=cut

sub visit_packages {
    my ($self, $visitor, $type) = @_;
    my @types;
    push @types, $type if $type;
    @types = keys %SUPPORTED_TYPES unless $type;
    foreach my $pkg_type (@types) {
        my $index = $self->_get_lab_index ($pkg_type);
        my $intv = sub {
            my ($me, $pkg_name, $pkg_version, $pkg_arch) = @_;
            my $pkg_src = $me->{'source'}//$pkg_name;
            my $dir = $self->_pool_path ($pkg_src, $pkg_type, $pkg_name, $pkg_version, $pkg_arch);
            my $pkg_src_version = $me->{'source-version'};
            my $lentry = Lintian::Lab::Entry->_new ($self, $pkg_name, $pkg_version, $pkg_arch,
                                                   $pkg_type, undef, $pkg_src, $pkg_src_version, $dir);
            $visitor->($lentry, $pkg_name, $pkg_version, $pkg_arch);
        };
        $index->visit_all ($intv);
    }
}


# Non-API method used by reporting to look up the manifest data via the Lab
# rather than bypassing it.
sub _get_lab_manifest_data {
    my ($self, $pkg_name, $pkg_type, @keys) = @_;
    my $index = $self->_get_lab_index ($pkg_type);
    if (scalar @keys >= 2 || (scalar @keys >= 1 && $pkg_type eq 'source')) {
        # All we need to know
        return $index->get ($pkg_name, @keys);
    } else {
        # Time to guess (or hope)
        my @result = ();
        my $searcher = sub {
            my ($v) = @_;
            push @result, $v;
        }; # end searcher
        $index->visit_all ($searcher, $pkg_name, @keys);
        return $result[0] if @result;
    }
    # Nothing so far, then it does not exist
    return;
}

# Returns the index of packages in the lab of a given type (of packages).
#
# Unlike $lab->_load_lab_index, this uses the cached version if it is
# available.
#
# Note this is also used by reporting/html_reports
sub _get_lab_index {
    my ($self, $pkg_type) = @_;
    croak "Undefined (or empty) package type" unless $pkg_type;
    croak "Unknown package type $pkg_type" unless $SUPPORTED_TYPES{$pkg_type};
    # Fetch (or load) the index of that type
    return $self->{'state'}->{$pkg_type} // $self->_load_lab_index ($pkg_type);
}

# Unconditionally (re-)loads the index of packages in the lab of a
# given type (of packages).
#
# $lab->_get_lab_index is generally faster since it uses the cache if
# available.
sub _load_lab_index {
    my ($self, $pkg_type) = @_;
    my $dir = $self->dir;
    my $manifest = Lintian::Lab::Manifest->new ($pkg_type);
    my $lif = "$dir/info/${pkg_type}-packages";
    $manifest->read_list ($lif);
    $self->{'state'}->{$pkg_type} = $manifest;
    return $manifest;
}

# Given the package meta data (src_name, type, name, version, arch) return the
# path to it in the Lab.  The path returned will be absolute.
sub _pool_path {
    my ($self, $pkg_src, $pkg_type, $pkg_name, $pkg_version, $pkg_arch) = @_;
    my $dir = $self->dir;
    my $p;
    # If it is at least 4 characters and starts with "lib", use "libX"
    # as prefix
    if ($pkg_src =~ m/^lib./o) {
        $p = substr $pkg_src, 0, 4;
    } else {
        $p = substr $pkg_src, 0, 1;
    }
    $p  = "$p/$pkg_src/${pkg_name}_${pkg_version}";
    $p .= "_${pkg_arch}" unless $pkg_type eq 'source';
    $p .= "_${pkg_type}";
    # Turn spaces into dashes - spaces do appear in architectures
    # (i.e. for changes files).
    $p =~ s/\s/-/go;
    # Also replace ":" with "_" as : is usually used for path separator
    $p =~ s/:/_/go;
    return "$dir/pool/$p";
}

=item generate_diffs (LIST)

Each member of LIST must be a L<Lintian::Lab::Manifest>.

The lab will generate a diff between the given member and its state
for the given package type.

The diffs are accurate until the original manifest is modified or a
package is added or removed to the lab.

=cut

sub generate_diffs {
    my ($self, @lists) = @_;
    my $labdir = $self->dir;
    my @diffs;
    croak "$labdir is not a valid lab (run lintian --setup-lab first?).\n"
        unless $self->is_open;
    foreach my $list (@lists) {
        my $type = $list->type;
        my $lab_list;
        $lab_list = $self->_get_lab_index ($type);
        push @diffs, $lab_list->diff ($list);
    }
    return @diffs;
}

=item repair_lab

Checks the lab contents against the current meta-data and syncs them.
The lab must be open and should not be access while this method is
running.

This returns the number of corrections done by this process.  If there
were any corrections, the state files are written before returning.

The method may croak if it is unable to do a full check of the lab or
if it is unable to write the corrected metadata.

Note: This may (and generally will) correct "broken" entries by
removing them.

=cut

sub repair_lab {
    my ($self) = @_;
    my $updates = 0;
    croak "Lab is not open.\n" unless $self->is_open;
    foreach my $pkg_type (keys %SUPPORTED_TYPES) {
        my $index = $self->_get_lab_index ($pkg_type);
        my $visitor = sub {
            my ($metadata, @keys) = @_;
            my ($pkg_name, $pkg_version, $pkg_arch) = @keys;
            my $pkg_src = $metadata->{'source'}//$pkg_name;
            my $pkg_src_version = $metadata->{'source-version'};
            my $dir = $self->_pool_path ($pkg_src, $pkg_type, $pkg_name, $pkg_version, $pkg_arch);
            my $entry;
            unless ( -d $dir && -f "$dir/.lintian-status") {
                # The entry is clearly not here, remove it from the metadata
                $index->delete (@keys);
                $updates++;
                -d $dir && rmdir $dir;
                return;
            }
            eval {
                $entry = Lintian::Lab::Entry->_new ($self, $pkg_name, $pkg_version, $pkg_arch,
                                                    $pkg_type, undef, $pkg_src, $pkg_src_version,
                                                    $dir);
            };
            unless ($entry && $entry->exists) {
                # We either cannot load the entry or it does not
                # believe it exists - either way, the metadata is out
                # of date.
                if ($entry) {
                    $entry->remove;
                    # Strictly speaking $entry->remove ought to clean
                    # up the index for us, but fall through and do it
                    # anyway.
                } else {
                    # The entry is not here to clean up, lets purge it
                    # the good old fashioned way.
                    delete_dir ($dir);
                }
                $index->delete (@keys);
                $updates++;
            }
        };

        $index->visit_all ($visitor);
    }

    # FIXME: scan the pool for entries not in the metadata.

    $self->_write_manifests;

    return $updates;
}

=item create ([OPTS])

Creates a new lab.  It will create L</dir> if it does not exist.
It will also create a basic empty lab.  If this is a temporary
lab, this method will also setup the temporary dir for the lab.

The lab will I<not> be opened by this method.  This should be done
afterwards by invoking the L</open> method.

OPTS (if present) is a hashref containing options.  The following
options are accepted:

=over 4

=item keep-lab

If "keep-lab" points to a truth value the temporary directory will
I<not> be removed by closing the lab (nor exiting the application).
However, explicitly calling L</remove> will remove the lab.

=item mode

If present, this will be used as mode for creating directories.  Will
default to 0777 if not specified.  It is passed to mkdir and is thus
subject to umask settings.

=back

Note: This will not create parent directories of L</dir> and will
croak if these does not exist.

Note: This may update the value of L</dir> as resolving the path
requires it to exist.

Note: This does nothing if the lab appears to already exists.

=cut

sub create {
    my ($self, $opts) = @_;
    my $dir = $self->dir;
    my $mid = 0;
    my $mode = 0777;

    return 1 if $self->exists;

    $opts = {} unless $opts;
    $mode = $opts->{'mode'} if exists $opts->{'mode'};
    if ( !$dir or $self->is_temp) {
        if ($self->is_temp) {
            my $keep = $opts->{'keep-lab'}//0;
            my %topts = ( 'CLEANUP' => !$keep, 'TMPDIR' => 1 );
            my $t = tempdir ('temp-lintian-lab-XXXXXXXXXX', %topts);
            $dir = Cwd::abs_path ($t);
            croak "Could not resolve $t: $!" unless $dir;
            $self->{'dir'} = $dir;
            $self->{'keep-lab'} = $keep;
        } else {
            # This should not be possible - but then again,
            # code should not have any bugs either...
            croak 'Lab path may not be empty for a static lab';
        }
    }
    # Create the top dir if needed - note due to Lintian::Lab->new
    # and the above tempdir creation code, we know that $dir is
    # absolute.
    croak "Cannot create $dir: $!" unless -d $dir or mkdir $dir, $mode;

    if ($self->{'_correct_dir'}) {
        # This happens if $dir has been created in this call.
        # Until now we have been unable to fully resolve the path,
        # so we try now.
        my $absdir = Cwd::abs_path ($dir);
        croak "Cannot resolve $dir: $!" unless $absdir;
        delete $self->{'_correct_dir'};
        $dir = $absdir;
        $self->{'dir'} = $absdir;
    }

    # Top dir exists, time to create the minimal directories.
    unless (-d "$dir/info") {
        mkdir "$dir/info", $mode or croak "mkdir $dir/info: $!";
        $mid = 1; # remember we created the info dir
    }

    unless (-d "$dir/pool") {
        unless (mkdir "$dir/pool", $mode) {
            my $err = $!; # store the error
            # Remove the info dir if we made it.  This attempts to
            # prevent a semi-created lab that the API cannot remove
            # again.
            #
            # ignore the error (if any) - we can only do so much
            rmdir "$dir/info" if $mid;
            $! = $err;
            croak "mkdir $dir/pool: $!";
        }
    }
    # Okay - $dir/info and $dir/pool exists... The subdirs in
    # $dir/pool will be created as needed.

    # Create the meta-data file - note at this point we can use
    # $lab->remove
    my $ok = 0;
    eval {
        open my $lfd, '>', "$dir/info/lab-info" or croak "opening $dir/info/lab-info: $!";

        print $lfd 'Lab-Format: ' . LAB_FORMAT . "\n";
        print $lfd "Layout: pool\n";

        close $lfd or croak "closing $dir/info/lab-info: $!";
        $ok = 1;
    };
    unless ($ok) {
        my $err = $@;
        eval { $self->remove; };
        croak $err;
    }
    return 1;
}

=item open

Opens the lab and reads the contents into caches.  If the lab is
temporary and does not exists, this method will call create to
initialize the temporary lab.

This will croak if the lab is already open.  It may also croak for
the same reasons as L</create> if the lab is temporary.

Note: for static labs, L</dir> must point to an existing consistent
lab or this will croak.  To open a new lab, please use L</create>.

Note: It is not possible to pass options to the creation of the
temporary lab.  If special options are required, please use
L</create> directly.

=cut

sub open {
    my ($self) = @_;
    my $dir;
    my $msg = "Open Lab failed";
    croak ('Lab is already open') if $self->is_open;
    if ($self->is_temp) {
        $self->create unless $self->exists;
        $dir = $self->dir;
    } else {
        $dir = $self->dir;
        unless ($self->exists) {
            croak "$msg: $dir does not exists" unless -e $dir;
            croak "$msg: $dir is not a lab or the lab is corrupt";
        }
    }

    unless ( -e "$dir/info/lab-info") {
        if ( $self->exists ) {
            croak "$msg: The Lab format is not supported";
        }
        croak "$msg: Lab is corrupt - $dir/info/lab-info does not exist";
    }

    # Check the lab-format - this ought to be redundant for temp labs, but
    # it's simpler to do it for them anyway.
    my $header = get_dsc_info ("$dir/info/lab-info");
    my $format = $header->{'lab-format'}//'';
    my $layout = $header->{'layout'}//'pool';
    unless ($format && $format eq LAB_FORMAT) {
        croak "$msg: Lab format $format is not supported ($dir)" if $format;
        croak "$msg: No lab format specification in $dir/info/lab-info";
    }
    unless ($layout && lc($layout) eq 'pool') {
        # Unknown layout style?
        croak "$msg: Layout field present but with no value" unless $layout;
        croak "$msg: Implementation does not support the layout \"$layout\"";
    }

    # Looks decent so far
    $self->{'lab-info'} = $header;
    $self->{'is_open'} = 1;
    return 1;
}

=item close

Close the lab - all state caches will be flushed to the disk and the
lab can no longer be used.  All references to entries in the lab
should be considered invalid.

Note: if the lab is a temporary one, this will be deleted unless it
was created with "keep-lab" (see L</create>).

=cut

sub close {
    my ($self) = @_;
    return unless $self->exists;
    if ($self->is_temp && !$self->{'keep-lab'}) {
        # Temporary lab (without "keep-lab" property)
        $self->remove;
    } else {
        $self->_write_manifests;
    }
    $self->{'state'} = {};
    $self->{'is_open'} = 0;
    $self->{'lab-info'} = {};
    return 1;
}

sub _write_manifests {
    my ($self) = @_;
    my $dir = $self->dir;
    while ( my ($pkg_type, $plist) = (each %{ $self->{'state'} }) ) {
        # write_list croaks on error, so no need for "or croak/die"
        $plist->write_list ("$dir/info/${pkg_type}-packages")
            if $plist->dirty;
    }
}

=item remove

Removes the lab and everything in it.  Any reference to an entry
returned from this lab will immediately become invalid.

If this is a temporary lab, the lab root dir (as returned L</dir>)
will be removed as well on success.  Otherwise the lab root dir will
not be removed by this call.

On success, this will return a truth value.  If the lab is a temporary
lab, the directory path will be set to the empty string (that is,
L</dir> will return '').

On error, this method will croak.

If the lab has already been removed (or does not exist), this will
return a truth value.

=cut

sub remove {
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
            croak "$dir: Does not look like a lab";
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
            croak "delete_dir (\$contents): $!";
        }
    }

    # dynamic lab?
    if ($self->is_temp) {
        rmdir $dir or croak "rmdir $dir: $!";
        $self->{'dir'} = '';
    }

    $self->{'is_open'} = 0;
    return 1;
}

=item is_temp

Returns a truth value if lab is a temporary lab.

Note: This returns a truth value, even if the lab was created with the
"keep-lab" property.

=cut

sub is_temp {
    my ($self) = @_;
    return $self->{'mode'} eq LAB_MODE_TEMP ? 1 : 0;
}

# initialize the instance
#
# May be overriden by a sub-class.
#
# $self->dir may be the empty string if this is a temporary lab.
sub _init {
    my ($self) = @_;
}

# event - triggered by Lintian::Lab::Entry
sub _entry_removed {
    my ($self, $entry) = @_;
    my $pkg_name    = $entry->pkg_name;
    my $pkg_type    = $entry->pkg_type;
    my $pkg_version = $entry->pkg_version;
    my @keys = ($pkg_name, $pkg_version);
    my $pf = $self->_get_lab_index ($pkg_type);

    push @keys, $entry->pkg_arch if $pkg_type ne 'source';

    $pf->delete (@keys);
}

# event - triggered by Lintian::Lab::Entry
sub _entry_created {
    my ($self, $entry) = @_;
    my $pkg_name    = $entry->pkg_name;
    my $pkg_type    = $entry->pkg_type;
    my $pkg_version = $entry->pkg_version;
    my $pkg_path    = $entry->pkg_path;
    my $ts = 0;
    my $pf = $self->_get_lab_index ($pkg_type);
    my %data = (
        'file'    => $pkg_path,
        'version' => $pkg_version,
    );

    if (my @stat = stat $pkg_path) {
        $ts = $stat[9];
    }
    $data{'timestamp'} = $ts;
    if ($pkg_type eq 'source') {
        my $info = $entry->info;
        my $up = $info->field ('uploaders')//'';
        my $maint = $info->field ('maintainer')//'';
        my $bin = $info->field ('binary')//'';

        # Normalize the fields - usually this will be "no-ops", but we
        # do check some really warped packages every now and then...

        if ($up) {
            $up =~ s/\n/ /og;
            $up = join (', ', split (m/\s*,\s*/o, $up));
        }
        if ($bin) {
            $bin   =~ s/\n\s*//og;
            $bin = join (', ', split (m/\s*,\s*/o, $bin));
        }

        $maint =~ s/\n\s*//og if $maint;
        $data{'binary'}     = $bin;
        $data{'source'}     = $pkg_name;
        $data{'area'}       = ''; # just blank this - we do not know it :)
        $data{'maintainer'} = $maint;
        $data{'uploaders'}  = $up;
    } elsif ($pkg_type eq 'changes') {
        $data{'architecture'} = $entry->pkg_arch;
        $data{'source'}       = $pkg_name;
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
        my $info = $entry->info;
        my $area = 'main';
        my $s = $info->field ('section')//'';
        if ($s && $s =~ m,\s*([a-zA-Z0-9-_]+)/,o) {
            $area = $1;
        }
        $data{'architecture'}   = $entry->pkg_arch;
        $data{'area'}           = $area;
        $data{'package'}        = $pkg_name;
        $data{'source'}         = $entry->pkg_src;
        $data{'source-version'} = $entry->pkg_src_version;
    } else {
        croak "Unknown package type: $pkg_type";
    }

    $pf->set (\%data);
}

=back

=head1 Changes to the lab format.

Lab formats up to (and including) "10" used to store the lab format
with each entry.  The files in $LAB/info/ were used to list packages
from a mirror (dist).

In lab format 11 the lab format is stored in $LAB/info/lab-info.  The
rest of the files in $LAB/info/* have been re-purposed to be a list of
packages in the lab.

The $LAB/info/lab-info is parsed as a debian control file (See Debian
Policy Manual §5.1 for syntax).  The consists of a single paragraph
and only the following fields are allowed:

=over 4

=item Lab-Format (simple, mandatory)

This field contains the lab format of this lab.  Generally this is
simply an integer (though during development non-integers have been
used).

=item Layout (simple, optional)

The layout parameter describes how packages are stored in the lab.
Currently the only accepted value is "pool" and the value is not
case-sensitive.

The pool format dictates that packages are stored in:

 pool/$l/${name}/${name}_${version}[_${arch}]_${type}/

Note that $arch is left out for source packages, $l is the first
letter of the package name (except if the name starts with "lib", then
it is the first 4 letters of the package name).  Whitespaces (e.g. "
") are replaced with dashes ("-") and colons (":") with underscores
("_").

If the field is missing, it defaults to "pool".

=back

It is allowed to use comments in $LAB/info/lab-info as described
in the Debian Policy Manual §5.1.

=head1 AUTHOR

Niels Thykier <niels@thykier.net>

Based on the work of various others.

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

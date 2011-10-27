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

use Util qw(delete_dir get_dsc_info);

use Lintian::Lab::Entry;
use Lintian::Lab::Manifest;

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
 
 $lab->close_lab;

=head1 DESCRIPTION

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

=item $lab->get_package ($pkg_name, $pkg_type[, @extra]), $lab->get_package ($proc)

Fetches an existing package from the lab.

First argument can be a L<Lintian::Processable|proccessable>.  In that
case all other arguments are ignored.

If the first calling convention is used then this method will by
default search for an existing package.  The @extra argument cna be
used to narrow the search or even to add a new entry.

@extra consists of (in order):
 - version
 - arch (Ignored if $pkg_type is "source")
 - path to package

If version or arch is omitted (or undef) then that search parameter is
consider a wildcard for "any".  Example:

 # Returns all eclipse-platform packages with architecture i386 regardless
 # of their version (if any)
 @ps  = $lab->get_package ('eclipse-platform', 'binary', undef, 'i386');
 # Returns all eclipse-platform packages with version 3.5.2-11 regardless
 # of their architecture (if any)
 @ps  = $lab->get_package ('eclipse-platform', 'binary', '3.5.2-11');
 # Return the eclipse-platform package with version 3.5.2-11 and architecture
 # i386 (or undef)
 $pkg = $lab->get_package ('eclipse-platform', 'binary', '3.5.2-11', 'i386');


If all 3 @extra arguments are given, then the entry will be created if
it does not exists.

In list context, this returns a list of matches.  In scalar context
this returns the first match (if any).

=cut

sub get_package {
    my ($self, $pkg, $pkg_type, $pkg_version, $pkg_arch, $pkg_path) = @_;
    my $pkg_name;
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
            $pkg_src_version = $e->{'source-version'}//$pkg_version;
        }
        $dir = $self->_pool_path ($pkg_name, $pkg_type, $pkg_version, $pkg_arch);
        push @entries, Lintian::Lab::Entry->new ($self, $pkg_name, $pkg_version, $pkg_arch, $pkg_type, $pkg_path, $pkg_src, $pkg_src_version, $dir);
    } else {
        # clear $pkg_arch if it is a source package - it simplifies
        # the search code below
        undef $pkg_arch if $pkg_type eq 'source';
        my $searcher = sub {
            my ($entry, @keys) = @_;
            my ($n, $v, $a) = @keys;
            my $dir;
            my $pp;
            # We do not have to check version - if we have a specific
            # version, only entries with that version will be visited.
            return if defined $pkg_arch && $a ne $pkg_arch;
            $pp = $entry->{'file'};
            $dir = $self->_pool_path ($pkg_name, $pkg_type, $v, $a);
            push @entries,  Lintian::Lab::Entry->new ($self, $pkg_name, $v, $a, $pkg_type, $pp, $entry->{'source'}, $entry->{'source-version'}//$v, $dir);
        };
        my @sk = ($pkg_name);
        push @sk, $pkg_version if defined $pkg_version;
        $index->visit_all ($searcher, @sk);
    }

    return wantarray ? @entries : $entries[0];
}

# Returns the index of packages in the lab of a given type (of packages).
#
# Unlike $lab->_load_lab_index, this uses the cache'd version if it is
# available.
sub _get_lab_index {
    my ($self, $pkg_type) = @_;
    croak "Unknown package type $pkg_type" unless $SUPPORTED_TYPES{$pkg_type};
    # Fetch (or load) the index of that type
    return $self->{'state'}->{$pkg_type} // $self->_load_lab_index ($pkg_type);
}

# Unconditionally (Re-)loads the index of packages in the lab of a
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

# Given the package meta data (name, type, version, arch) return the
# path to it in the Lab.  Path returned will be absolute.
sub _pool_path {
    my ($self, $pkg_name, $pkg_type, $pkg_version, $pkg_arch) = @_;
    my $dir = $self->dir;
    my $p;
    if ($pkg_name =~ m/^lib/o) {
        $p = substr $pkg_name, 0, 4;
    } else {
        $p = substr $pkg_name, 0, 1;
    }
    $p  = "$p/$pkg_name/${pkg_name}_${pkg_version}";
    $p .= "_${pkg_arch}" unless $pkg_type eq 'source';
    $p .= "_${pkg_type}";
    # Turn spaces into dashes - spaces do appear in architectures
    # (i.e. for changes files).
    $p =~ s/\s/-/go;
    # Also replace ":" with "_" as : is usually used for path separator
    $p =~ s/:/_/go;
    return "$dir/pool/$p";
}

# lab->generate_diffs(@lists)
#
# Each member of @lists must be a Lintian::Lab::Manifest.
#
# The lab will generate a diff between the given member and its
# state for the given package type.  The diffs are returned in the
# same order as they appear in @lists.
#
# The diffs are valid until the original list is modified or a
# package is added or removed to the lab.
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


=item $lab->create_lab ([$opts])

Creates a new lab.  It will create $lab->dir if it does not exists.
It will also create a basic lab empty lab.  If this is a temporary
lab, this method will also setup the temporary dir for the lab.

B<$opts> (if present) is a hashref containing options.  The following
options are accepted:

=over 4

=item keep-lab

If "keep-lab" points to a truth value the temporary directory will
I<not> be removed by closing the lab (nor exiting the application).
However, explicitly calling $lab->remove_lab will remove the lab.

=item mode

If present, this will be used as mode for creating directories.
Will default to 0777 if not specified.

=back

Note: This will not create parent directories of $lab->dir and will
croak if these does not exists.

Note: This may update the value of $lab->dir as resolving the path
requires it to exists.

Note: This does nothing if the lab appears to already exists.

=cut

sub create_lab {
    my ($self, $opts) = @_;
    my $dir = $self->dir;
    my $mid = 0;
    my $mode = 0777;

    return if $self->lab_exists;

    $opts = {} unless $opts;
    $mode = $opts->{'mode'} if exists $opts->{'mode'};
    if ( !$dir or $self->{'mode'} eq LAB_MODE_TEMP) {
        if ($self->{'mode'} eq LAB_MODE_TEMP) {
            my $keep = $opts->{'keep-lab'}//0;
            my $topts = { CLEAN => !$keep, TMPDIR => 1 };
            my $t = tempdir ('temp-lintian-lab-XXXXXX', $topts);
            $dir = Cwd::abs_path ($t);
            croak "Could not resolve $dir: $!" unless $dir;
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
    # $lab->remove_lab
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
        eval { $self->remove_lab; };
        croak $err;
    }
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
    my $dir;
    my $msg = "Open Lab failed";
    croak ('Lab is already open') if $self->is_open;
    if ($self->{'mode'} eq LAB_MODE_TEMP) {
        $self->create_lab unless $self->lab_exists;
        $dir = $self->dir;
    } else {
        $dir = $self->dir;
        unless ($self->lab_exists) {
            croak "$msg: $dir does not exists" unless -e $dir;
            croak "$msg: $dir is not a lab or the lab is corrupt";
        }
    }

    unless ( -e "$dir/info/lab-info") {
        if ( $self->lab_exists ) {
            croak "$msg: The Lab format is not supported";
        }
        croak "$msg: Lab is corrupt - $dir/info/lab-info does not exists";
    }

    # Check the lab-format - this ought to be redundant for temp labs, but
    # it simple to do it that way.
    my $header = get_dsc_info ("$dir/info/lab-info");
    my $format = $header->{'lab-format'}//'';
    my $layout = $header->{'layout'}//'pool';
    unless ($format && $format eq LAB_FORMAT) {
        croak "$msg: Lab format $format is not supported ($dir)" if $format;
        croak "$msg: No lab format specification in $dir/info/lab-info";
    }
    if ($layout && lc($layout) ne 'pool') {
        # Unknown layout style?
        croak "$msg: Implementation does not support the layout \"$layout\"";
    }

    # Looks decent so far
    $self->{'lab-info'} = $header;
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
    return unless $self->lab_exists;
    if ($self->{'mode'} eq LAB_MODE_TEMP && !$self->{'keep-lab'}) {
        # Temporary lab (without "keep-lab" property)
        $self->remove_lab;
    } else {
        my $dir = $self->dir;
        while ( my ($pkg_type, $plist) = (each %{ $self->{'state'} }) ) {
            # write_list croaks on error, so no need for "or croak/die"
            $plist->write_list ("$dir/info/${pkg_type}-packages");
        }
    }
    $self->{'state'} = {};
    $self->{'is_open'} = 0;
    $self->{'lab-info'} = {};
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
    if ($self->{'mode'} eq LAB_MODE_TEMP) {
        rmdir $dir or croak "rmdir $dir: $!";
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
        $data{'area'}           = 'main';
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

In Lab format 11 the lab format is stored in $LAB/info/lab-info.  The
rest of the files in $LAB/info/* has been re-purposed to be a list of
packages in the lab.

The $LAB/info/lab-info file also contain modifying parameters.  All
parameters are matched case-insensitively and the accepted parameters
are:

=over 4

=item Layout

The layout parameter describes how packages are stored in the lab.
Currently the only accepted value is "pool" and the value is not
case-sensitive.

The pool format dictates that packages are stored in:

 pool/$l/${name}/${name}_${version}[_${arch}]_${type}/

Note that $arch is left out for source packages, $l is the first
letter of the package name (except if the name starts with "lib", then
it is the first 4 letters of the package name).  Whitespaces (i.e. "
") are replaced with dashes ("-") and colons (":") with underscores
"_".

If the field is missing, it defaults to "pool".

=back

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

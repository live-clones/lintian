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

# Lab format Version Number increased whenever incompatible changes
# are done to the lab so that all packages are re-unpacked
use constant LAB_FORMAT => 10.1;


# Export now due to cicular depends between Lab and Lab::Package.
our (@EXPORT, @EXPORT_OK, %EXPORT_TAGS);

BEGIN {
    @EXPORT = ();
    %EXPORT_TAGS = (
        constants => [qw(LAB_FORMAT)],
        );
    @EXPORT_OK = (
        @{$EXPORT_TAGS{constants}}
        );
};

=head1 NAME

Lintian::Lab -- Interface to the Lintian Lab

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
    my $mode = 'temporary';
    if ($dir) {
        $absdir = Cwd::abs_path($dir);
        croak "Cannot resolve $dir: $!" unless $absdir;
        $mode = 'static';
    }
    my $self = {
        'dir'   => $absdir,
        'state' => {},
        'mode'  => $mode,
    };
    bless $self, $class;
    $self->_init ($dir);
    return $self;
}

=item $lab->dir

Returns the absolute path to the base of the lab.

=cut

Lintian::Lab->mk_ro_accessors (qw(dir));

=item $lab->auto_remove ([$val])

Whether or not to auto-remove the lab.  By default, temporary labs will
be auto-removed and static labs will not.  The removal will happen when
C<$lab> goes out of scope.

=cut

Lintian::Lab->mk_accessors (qw(auto_remove));

=item $lab->is_valid_lab

Returns a truth value if B<$lab> points to a valid and existing
lab.

=cut

sub is_valid_lab {
    my ( $self ) = @_;
    my $dir = $self->{dir};
    return unless $dir;
    # New style lab?
    return 1 if -d "$dir/info" && -d "$dir/pool";
    # 10-style lab?
    return -d "$dir/binary"
	&& -d "$dir/udeb"
	&& -d "$dir/source"
	&& -d "$dir/info";
}

sub get_package {
    croak "Not implemented";
}

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

=item $lab->remove_lab

Removes the lab and everything in it.  Any reference to an entry
returned from this lab will immediately become invalid.

If this is a temporary lab, the lab root dir (as returned $lab->dir)
will be removed as well on success.  Otherwise the lab root dir will
not be removed by this call.

On success, this will return a truth value and the directory path will
be set to the empty string (that is, $lab->dir will return '').  It
will not be possible to use B<$lab> to create a new lab.

On error, this method will croak.

If the lab has already been removed, this will return a truth value.

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
    if ($self->{mode} eq 'temporary') {
        croak "rmdir $dir: $!";
    }

    $self->{dir} = '';
    return 1;
}

# initialize the instance
#
# May be overriden by a sub-class
sub _init {
    my ($self, $dir) = @_;

}

=back

=head1 AUTHOR

Niels Thykier <niels@thykier.net>

Based on the work of various others.

=cut


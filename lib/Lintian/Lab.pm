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

use parent qw(Class::Accessor::Fast);

use Carp qw(croak);
use Cwd();
use File::Temp qw(tempdir); # For temporary labs
use Path::Tiny;

# A private table of supported types.
my %SUPPORTED_TYPES = (
    'binary'  => 1,
    'buildinfo' => 1,
    'changes' => 1,
    'source'  => 1,
    'udeb'    => 1,
);

use Lintian::Collect;
use Lintian::Lab::Entry;
use Lintian::Util qw(get_dsc_info);

use constant EMPTY => q{};

=encoding utf8

=head1 NAME

Lintian::Lab -- Interface to the Lintian Lab

=head1 SYNOPSIS

 use Lintian::Lab;
 
 my $lab = Lintian::Lab->new;

 if (!$lab->exists) {
     $lab->create;
 }
 $lab->open;
 $lab->close;

=head1 DESCRIPTION

This module provides an abstraction from "How and where" packages are
placed.  It handles creation and deletion of the Lintian Lab itself as
well as providing access to the entries.

=head1 CLASS METHODS

=over 4

=item new

Creates a new Lab instance.  The lab will be temporary and will point
to a temporary directory.

=cut

sub new {
    my ($class) = @_;
    my $dok = 1;

    my $self = {
        # Must be absolute (frontend/lintian depends on it)
        #  - also $self->dir promises this
        #  - it may be the empty string (see $self->dir)
        'dir'         => EMPTY,
        'is_open'     => 0,
        'keep-lab'    => 0,
    };
    $self->{'_correct_dir'} = 1 unless $dok;
    bless $self, $class;
    return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item is_open

Returns a truth value if this lab is open.

Note: If the lab is open, it also exists.  However, if the lab is
closed then the lab may or may not exist (see L</exists>).

=cut

Lintian::Lab->mk_ro_accessors(qw(dir is_open));

=item exists

Returns a truth value if the instance points to an existing lab.

Note: This never implies that the lab is open.  Though it may imply
the lab is closed (see L</is_open>).

=cut

sub exists {
    my ($self) = @_;
    my $dir = $self->dir;
    return 1 if $dir and -d "$dir/pool";
    return;
}

=item get_package (PROC)

Fetches an existing package from the lab.

The first argument must be a L<processable|Lintian::Processable>.

=cut

sub get_package {
    my ($self, $proc) = @_;
    my ($entry, $dir, $pkg_type);

    croak 'Lab is not open' unless $self->is_open;

    if ($proc->isa('Lintian::Lab::Entry') and $proc->from_lab($self)) {
        # Shouldn't happen too often, but ...
        return $proc;
    }
    $pkg_type = $proc->pkg_type;

    # get_package only works with "real" types (and not views).
    croak "Not a supported type ($pkg_type)"
      unless exists $SUPPORTED_TYPES{$pkg_type};

    $dir = $self->_pool_path($proc->pkg_src,$pkg_type,$proc->pkg_name,
        $proc->pkg_version,$proc->pkg_arch);
    $entry = Lintian::Lab::Entry->_new_from_proc($proc, $self, $dir);
    return $entry;
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

=item create ([OPTS])

Creates a basic empty lab. Will also set up the temporary dir for
the lab.

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

Note: This does nothing if the lab appears to already exists.

=cut

sub create {
    my ($self, $opts) = @_;
    my $mid = 0;
    my $mode = 0777;

    return 1 if $self->exists;

    $opts = {} unless $opts;
    $mode = $opts->{'mode'} if exists $opts->{'mode'};

    my $keep = $opts->{'keep-lab'}//0;
    my %topts = ('CLEANUP' => !$keep, 'TMPDIR' => 1);
    my $t = tempdir('temp-lintian-lab-XXXXXXXXXX', %topts);
    my $dir = Cwd::abs_path($t);
    croak "Could not resolve $t: $!" unless $dir;
    $self->{'dir'} = $dir;
    $self->{'keep-lab'} = $keep;

    croak "Cannot create $dir: $!"
      unless -d $dir;

    if (not -d "$dir/pool" and not mkdir "$dir/pool", $mode) {
        croak "mkdir $dir/pool: $!";
    }
    # Okay - $dir/pool exists... The subdirs in $dir/pool will be
    # created as needed.
    return 1;
}

=item open

Opens the lab and reads the contents into caches.  If the lab does
not exist, this method will call create to initialize it.

This will croak if the lab is already open.  It may also croak for
the same reasons as L</create>.

Note: It is not possible to pass options to the creation of the
lab.  If special options are required, please use
L</create> directly.

=cut

sub open {
    my ($self) = @_;
    my $dir;
    my $msg = 'Open Lab failed';
    croak('Lab is already open') if $self->is_open;

    $self->create unless $self->exists;
    $dir = $self->dir;
    $self->{'is_open'} = 1;
    return 1;
}

=item close

Close the lab - the lab can no longer be used.  All references to
entries in the lab should be considered invalid.

Note: The lab will be deleted unless it was created with "keep-lab"
(see L</create>).

=cut

sub close {
    my ($self) = @_;
    return unless $self->exists;
    if (!$self->{'keep-lab'}) {
        $self->remove;
    }
    $self->{'is_open'} = 0;
    return 1;
}

=item remove

Removes the lab and everything in it.  Any reference to an entry
returned from this lab will immediately become invalid.

The lab root dir will be removed as well on success.

On success, this will return a truth value. The directory path will
be set to the empty string.

On error, this method will croak.

If the lab has already been removed (or does not exist), this will
return a truth value.

=cut

sub remove {
    my ($self) = @_;
    my $dir = $self->dir;
    my $empty = 0;

    return 1 if not $dir;

    if (-d $dir) {
        path($dir)->remove_tree;
    }
    $self->{'dir'} = '';
    $self->{'is_open'} = 0;
    return 1;
}

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

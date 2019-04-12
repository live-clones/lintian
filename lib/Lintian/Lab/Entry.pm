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
 
 my $lab = Lintian::Lab->new ("dir");
 my $lpkg = $lab->get_package ("name", "type", "version", "arch");
 
 # create the entry
 $lpkg->create;
 
 # obtain a Lintian::Collect object.
 my $info = $lpkg->info;
 
 $lpkg->clear_cache;
 
 # Remove package from lab.
 $lpkg->remove;

=head1 DESCRIPTION

This module provides basic access and manipulation about an entry
(i.e. processable) stored in the Lab.  Instances of this class
are not created directly, instead they are returned by various
methods from L<Lintian::Lab>.

=head1 CLASS METHODS

=over 4

=cut

use strict;
use warnings;

use parent qw(Lintian::Processable Class::Accessor::Fast);

use Carp qw(croak);
use Cwd();
use File::Spec;
use IO::Async::Loop;
use IO::Async::Routine;
use Path::Tiny;
use Scalar::Util qw(refaddr);

use Lintian::Lab;
use Lintian::Util qw(strip);

=item new_from_metadata (PKG_TYPE, METADATA, LAB, BASEDIR)

Overrides same constructor in Lintian::Processable.

Used by L<Lintian::Lab> to load an existing entry from the lab.

=cut

sub new_from_metadata {
    my ($type, $pkg_type, $metadata, $lab, $base_dir) = @_;
    my $self;
    my $pkg_path;
    $pkg_path = $metadata->{'pkg_path'}
      if exists $metadata->{'pkg_path'};
    {
        # Create a phony pkg_path if missing
        local $metadata->{'pkg_path'} = '<PLACEHOLDER>'
          unless exists $metadata->{'pkg_path'};
        $self = $type->SUPER::new_from_metadata($pkg_type, $metadata);
    }
    $self->{lab}      = $lab;
    $self->{info}     = undef; # load on demand.
    $self->{base_dir} = $base_dir;
    $self->{pkg_path} = $pkg_path; # Could be undef, _init will fix that

    return $self;
}

# private constructor (called by Lintian::Lab)
sub _new_from_proc {
    my ($type, $proc, $lab, $base_dir) = @_;
    my $self = {};
    bless $self, $type;
    $self->{pkg_name}        = $proc->pkg_name;
    $self->{pkg_version}     = $proc->pkg_version;
    $self->{pkg_type}        = $proc->pkg_type;
    $self->{pkg_src}         = $proc->pkg_src;
    $self->{pkg_src_version} = $proc->pkg_src_version;
    $self->{pkg_path}        = $proc->pkg_path;
    $self->{lab}             = $lab;
    $self->{info}            = undef; # load on demand.

    if ($self->pkg_type ne 'source') {
        $self->{pkg_arch} = $proc->pkg_arch;
    } else {
        $self->{pkg_arch} = 'source';
    }

    $self->{base_dir} = $base_dir;
    $self->_make_identifier;

    if ($proc->isa('Lintian::Processable::Package')) {
        my $ctrl = $proc->_ctrl_fields;
        if ($ctrl) {
            # The processable has already loaded the fields, cache them to save
            # info from doing it later...
            $self->{info}
              = Lintian::Collect->new($self->pkg_name, $self->pkg_type,
                $self->base_dir, $ctrl);
        }
    }
    return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item base_dir

Returns the base directory of this package inside the lab.

=item lab

Returns a reference to the laboratory related to this entry.

=cut

Lintian::Lab::Entry->mk_ro_accessors(qw(lab base_dir));

=item from_lab (LAB)

Returns a truth value if this entry is from LAB.

=cut

sub from_lab {
    my ($self, $lab) = @_;
    return refaddr $lab eq refaddr $self->{'lab'} ? 1 : 0;
}

=item info

Returns the L<info|Lintian::Collect> object associated with this entry.

Overrides info from L<Lintian::Processable>.

=cut

sub info {
    my ($self) = @_;
    my $info;
    $info = $self->{info};
    if (!defined $info) {
        croak('Cannot load info, entry does not exist') unless $self->exists;

        $info = Lintian::Collect->new($self->pkg_name, $self->pkg_type,
            $self->base_dir);
        $self->{info} = $info;
    }
    return $info;
}

=item clear_cache

Clears any caches held; this includes discarding the L<info|Lintian::Collect> object.

Overrides clear_cache from L<Lintian::Processable>.

=cut

sub clear_cache {
    my ($self) = @_;
    delete $self->{info};
    return;
}

=item remove

Removes all unpacked parts of the package in the lab.  Returns a truth
value if successful.

=cut

sub remove {
    my ($self) = @_;
    my $basedir = $self->{base_dir};
    return 1 if(!-e $basedir);
    $self->clear_cache;
    path($basedir)->remove_tree
      if -d $basedir;
    return 1;
}

=item exists

Returns a truth value if the entry exists.

=cut

sub exists {
    my ($self) = @_;
    my $pkg_type = $self->{pkg_type};
    my $base_dir = $self->{base_dir};

    # Check if the relevant symlink exists.
    if ($pkg_type eq 'changes'){
        return 1 if -l "$base_dir/changes";
    } elsif ($pkg_type eq 'buildinfo') {
        return 1 if -l "$base_dir/buildinfo";
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
        return 1 if -l "$base_dir/deb";
    } elsif ($pkg_type eq 'source'){
        return 1 if -l "$base_dir/dsc";
    }

    # No unpack level and no symlink => the entry does not
    # exist or it is too broken in its current state.
    return 0;
}

=item create

Creates a minimum entry, in which collections and checks
can be run.  Note if it already exists, then this will do
nothing.

=cut

sub create {
    my ($self) = @_;
    my $pkg_type = $self->{pkg_type};
    my $base_dir = $self->{base_dir};
    my $pkg_path = $self->{pkg_path};
    my $lab      = $self->{lab};
    my $link;
    my $madedir = 0;

    if (not -d $base_dir) {
        # In the pool we may have to create multiple directories. On
        # error we only remove the "top dir" and that is enough.
        system('mkdir', '-p', $base_dir) == 0
          or croak "mkdir -p $base_dir failed";
        $madedir = 1;
    } else {
        # If $base_dir exists, then check if the entry exists
        # - this is optimising for "non-existence" which is
        #   often the common case.
        return 0 if $self->exists;
    }
    if ($pkg_type eq 'changes'){
        $link = "$base_dir/changes";
    } elsif ($pkg_type eq 'buildinfo'){
        $link = "$base_dir/buildinfo";
    } elsif ($pkg_type eq 'binary' or $pkg_type eq 'udeb') {
        $link = "$base_dir/deb";
    } elsif ($pkg_type eq 'source'){
        $link = "$base_dir/dsc";
    } else {
        croak "create cannot handle $pkg_type";
    }
    unless (symlink($pkg_path, $link)){
        my $err = $!;
        # "undo" the mkdir if the symlink fails.
        rmdir $base_dir  if $madedir;
        $! = $err;
        croak "symlinking $pkg_path failed: $!";
    }
    if ($pkg_type eq 'source'){
        # If it is a source package, pull in all the related files
        #  - else unpacked will fail or we would need a separate
        #    collection for the symlinking.
        my (undef, $dir, undef) = File::Spec->splitpath($pkg_path);
        for my $fs (split(m/\n/o, $self->info->field('files'))) {
            strip($fs);
            next if $fs eq '';
            my @t = split(/\s+/o,$fs);
            next if ($t[2] =~ m,/,o);
            symlink("$dir/$t[2]", "$base_dir/$t[2]")
              or croak("cannot symlink file $t[2]: $!");
        }
    }
    return 1;
}

=back

=head1 AUTHOR

Niels Thykier <niels@thykier.net>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# -*- perl -*-
# Lintian::Collect::Package -- interface to data collection for packages

# Copyright (C) 2011 Niels Thykier
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

# This handles common things for things available in source and binary packages
package Lintian::Collect::Package;

use strict;
use warnings;
use base 'Lintian::Collect';

use Carp qw(croak);
use Util qw(perm2oct);

# Returns the path to the dir where the package is unpacked
#  or a file therein (see pod below)
# May croak if the package has not been unpacked.
# sub unpacked Needs-Info unpacked
sub unpacked {
    my ($self, $file) = @_;
    return $self->_fetch_extracted_dir('unpacked', 'unpacked', $file);
}

# Returns the information from collect/file-info
sub file_info {
    my ($self) = @_;
    return $self->{file_info} if exists $self->{file_info};
    my $base_dir = $self->base_dir();
    my %file_info;
    # sub file_info Needs-Info file-info
    open(my $idx, '<', "$base_dir/file-info")
        or fail("cannot open $base_dir/file-info: $!");
    while (<$idx>) {
        chomp;

        m/^(.+?)\x00\s+(.*)$/o
            or fail("an error in the file pkg is preventing lintian from checking this package: $_");
        my ($file, $info) = ($1,$2);

        $file =~ s,^\./,,o;
        $file =~ s,/+$,,o;

        $file_info{$file} = $info;
    }
    close $idx;
    $self->{file_info} = \%file_info;

    return $self->{file_info};
}

# Returns the information from the indices
# FIXME: should maybe return an object
# sub index Needs-Info index
sub index {
    my ($self) = @_;
    return $self->{index} if exists $self->{index};
    my $base_dir = $self->base_dir();
    my (%idx, %dir_counts);
    open my $idx, '<', "$base_dir/index"
        or fail("cannot open index file $base_dir/index: $!");
    open my $num_idx, '<', "$base_dir/index-owner-id"
        or fail("cannot open index file $base_dir/index-owner-id: $!");
    while (<$idx>) {
        chomp;

        my (%file, $perm, $owner, $name);
        ($perm,$owner,$file{size},$file{date},$file{time},$name) =
            split(' ', $_, 6);
        $file{operm} = perm2oct($perm);
        $file{type} = substr $perm, 0, 1;

        my $numeric = <$num_idx>;
        chomp $numeric;
        fail('cannot read index file index-owner-id') unless defined $numeric;
        my ($owner_id, $name_chk) = (split(' ', $numeric, 6))[1, 5];
        fail("mismatching contents of index files: $name $name_chk")
            if $name ne $name_chk;

        ($file{owner}, $file{group}) = split '/', $owner, 2;
        ($file{uid}, $file{gid}) = split '/', $owner_id, 2;

        $name =~ s,^\./,,;
        if ($name =~ s/ link to (.*)//) {
            $file{type} = 'h';
            $file{link} = $1;
            $file{link} =~ s,^\./,,;
        } elsif ($file{type} eq 'l') {
            ($name, $file{link}) = split ' -> ', $name, 2;
        }
        $file{name} = $name;

        # count directory contents:
        $dir_counts{$name} ||= 0 if $file{type} eq 'd';
        $dir_counts{$1} = ($dir_counts{$1} || 0) + 1
            if $name =~ m,^(.+/)[^/]+/?$,;

        $idx{$name} = \%file;
    }
    foreach my $file (keys %idx) {
        if ($dir_counts{$idx{$file}->{name}}) {
            $idx{$file}->{count} = $dir_counts{$idx{$file}->{name}};
        }
    }
    $self->{index} = \%idx;

    return $self->{index};
}

# Returns sorted file index (eqv to sort keys %{$info->index}), except it is cached.
#  sub sorted_index Needs-Info index
sub sorted_index {
    my ($self) = @_;
    my $index;
    my @result;
    return $self->{sorted_index} if exists $self->{sorted_index};
    $index = $self->index();
    @result = sort keys %{$index};
    $self->{sorted_index} = \@result;
    return \@result;
}



# Backing method for unpacked, debfiles and others; this is not a part of the
# API.
# sub _fetch_extracted_dir Needs-Info <>
sub _fetch_extracted_dir {
    my ($self, $field, $dirname, $file) = @_;
    my $dir = $self->{$field};
    if ( not defined $dir ) {
	my $base_dir = $self->base_dir;
	$dir = "$base_dir/$dirname";
	croak "$field ($dirname) is not available" unless -d "$dir/";
	$self->{$field} = $dir;
    }
    if ($file) {
	# strip leading ./ - if that leaves something, return the path there
	$file =~ s,^\.?/*+,,go;
	return "$dir/$file" if $file;
    }
    return $dir;
}


1;

=head1 NAME

Lintian::Collect::Package - Lintian base interface to binary and source package data collection

=head1 SYNOPSIS

    my ($name, $type) = ('foobar', 'source');
    my $collect = Lintian::Collect->new($name, $type);
    my $file;
    eval { $file = $collect->unpacked('/bin/ls'); };
    if ( $file && -e $file ) {
        # work with $file
        ;
    } elsif ($file) {
        print "/bin/ls is not available in the Package\n";
    } else {
        print "Package has not been unpacked\n";
    }

=head1 DESCRIPTION

Lintian::Collect::Package provides part of an interface to package
data for source and binary packages.  It implements data collection
methods specific to all packages that can be unpacked (or can contain
files)

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
source packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 INSTANCE METHODS

=over 4

=item unpacked([$name])

Returns the path to the directory in which the package has been
unpacked.  If C<$name> is given, it will return the path to that
specific file (or dir).  The method will strip any leading "./" and
"/" from C<$name>, but it will not check if C<$name> actually exists
nor will it check for path traversals.
  Caller is responsible for checking the sanity of the path passed to
unpacked and verifying that the returned path points to the expected
file.

The path returned is not guaranteed to be inside the Lintian Lab as
the package may have been unpacked outside the Lab (e.g. as
optimization).

The following code may be helpful in checking for path traversal:

 use Cwd qw(realpath);

 my $collect = ... ;
 my $file = '../../../etc/passwd';
 # Append slash to follow symlink if $collect->unpacked returns a symlink
 my $uroot = realpath($collect->unpacked() . '/');
 my $ufile = realpath($collect->unpacked($file));
 if ($ufile =~ m,^$uroot,) {
    # has not escaped $uroot
    do_stuff($ufile);
 } else {
    # escaped $uroot
    die "Possibly path traversal ($file)";
 }

Alternatively one can use Util::resolve_pkg_path.

=item file_info

Returns a hashref mapping file names to the output of file for that file.

Note the file names do not have any leading "./" nor "/".

=item index

Returns a hashref to the index information (permissions, file type etc).

Note the file names do not have any leading "./" nor "/".

=item sorted_index

Returns a sorted list of all files listed in index (or file_info hashref).

It may contain an "empty" entry denoting the "root dir".

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect(3), Lintian::Collect::Binary(3),
Lintian::Collect::Source(3)

=cut


# -*- perl -*-
# Lintian::Collect::Binary -- interface to binary package data collection

# Copyright (C) 2008 Russ Allbery
# Copyright (C) 2008 Frank Lichtenheld
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

package Lintian::Collect::Binary;
use strict;

use Lintian::Collect;
use Util;

our @ISA = qw(Lintian::Collect);

# Initialize a new binary package collect object.  Takes the package name,
# which is currently unused.
sub new {
    my ($class, $pkg) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Returns whether the package is a native package according to
# its version number
sub native {
    my ($self) = @_;
    return $self->{native} if exists $self->{native};
    my $version = $self->field('version');
    $self->{native} = ($version !~ m/-/);
}

# Returns the information from the indices
# FIXME: should maybe return an object
sub index {
    my ($self) = @_;
    return $self->{index} if exists $self->{index};

    my (@idx, %dir_counts);
    open my $idx, '<', "index"
        or fail("cannot open index file index: $!");
    open my $num_idx, '<', "index-owner-id"
        or fail("cannot open index file index-owner-id: $!");
    while (<$idx>) {
        chomp;

        my (%file, $perm, $owner, $name);
        ($perm,$owner,$file{size},$file{date},$file{time},$name) =
            split(' ', $_, 6);
        $file{operm} = perm2oct($perm);
        $file{type} = substr $perm, 0, 1;

        my $numeric = <$num_idx>;
        chomp $numeric;
        fail("cannot read index file index-owner-id") unless defined $numeric;
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

        push @idx, \%file;
    }
    foreach my $file (@idx) {
        if ($dir_counts{$file->{name}}) {
            $file->{count} = $dir_counts{$file->{name}};
        }
    }
    $self->{index} = \@idx;

    return $self->{index};
}

=head1 NAME

Lintian::Collect::Binary - Lintian interface to binary package data collection

=head1 SYNOPSIS

    my $collect = Lintian::Collect->new($name, $type);
    if ($collect->native) {
        print "Package is native\n";
    }

=head1 DESCRIPTION

Lintian::Collect::Binary provides an interface to package data for binary
packages.  It implements data collection methods specific to binary
packages.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
source packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 CLASS METHODS

=item new(PACKAGE)

Creates a new Lintian::Collect::Binary object.  Currently, PACKAGE is
ignored.  Normally, this method should not be called directly, only via
the Lintian::Collect constructor.

=back

=head1 INSTANCE METHODS

In addition to the instance methods listed below, all instance methods
documented in the Lintian::Collect module are also available.

=over 4

=item native()

Returns true if the binary package is native and false otherwise.
Nativeness will be judged by its version number.

=item index()

Returns a reference to an array of hash references with content
information about the binary package.  Each hash may have the
following keys:

=over 4

=item name

Name of the index entry without leading slash.

=item owner

=item group

=item uid

=item gid

The former two are in string form and may depend on the local system,
the latter two are the original numerical values as saved by tar.

=item date

Format "YYYY-MM-DD".

=item time

Format "hh:mm".

=item type

Entry type as one character.

=item operm

Entry permissions as octal number.

=item size

Entry size in bytes.  Note that tar(1) lists the size of directories as
0 (so this is what you will get) contrary to what ls(1) does.

=item link

If the entry is either a hardlink or symlink, contains the target of the
link.

=item count

If the entry is a directory, contains the number of other entries this
directory contains.

=back

=head1 AUTHOR

Originally written by Frank Lichtenheld <djpig@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround

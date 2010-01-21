# Copyright (C) 2008 Frank Lichtenheld <frank@lichtenheld.de>
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

package Lintian::Schedule;

use strict;
use warnings;

use Util;

sub new {
    my ($class, %options) = @_;
    my $self = {};

    bless($self, $class);

    $self->{opts} = \%options;
    $self->{schedule} = [];
    $self->{unique} = {};

    return $self;
}

# schedule a package for processing
sub add_file {
    my ($self, $type, $file, %pkg_info) = @_;

    my ($pkg, $ver, $arch);
    if ($type eq 's') {
	($pkg, $ver, $arch) =
	    (@pkg_info{qw(source version)}, 'source');
    } else {
	($pkg, $ver, $arch) =
	    @pkg_info{qw(package version architecture)};
    }
    $pkg  ||= '';
    # "0" is a valid version, so we can't use || here
    $ver  = '' unless length $ver;
    $arch ||= '';

    if ( $pkg =~ m,/, ) {
	warn(sprintf("warning: bad name for %2\$s package '%1\$s', skipping\n",
	    $pkg, $type eq 'b' ? 'binary' : ($type eq 's' ? 'source': 'udeb')));
	return 1;
    }

    my $s = "$type $pkg $ver $arch $file";
    my %h = ( type => $type, package => $pkg, version => $ver,
	      architecture => $arch, file => $file );

    if ( $self->{unique}{$s}++ ) {
	if ($self->{opts}{verbose}) {
	    printf "N: Ignoring duplicate %s package $pkg (version $ver)\n",
		$type eq 'b' ? 'binary' : ($type eq 's' ? 'source': 'udeb');
	}
	return 1;
    }

    push(@{$self->{schedule}}, \%h);
    return 1;
}

sub add_deb {
    my ($self, $type, $file) = @_;

    my $info = get_deb_info($file);
    return unless defined $info;
    return $self->add_file($type, $file, %$info);
}

sub add_dsc {
    my ($self, $file) = @_;

    my $info = get_dsc_info($file);
    return unless defined $info;
    return $self->add_file('s', $file, %$info);
}

sub add_pkg_list {
    my ($self, $packages_file) = @_;

    open(IN, '<', $packages_file)
	or die("cannot open packages file $packages_file for reading: $!");
    while (<IN>) {
	chomp;
	my ($type, $pkg, $ver, $file) = split(/\s+/, $_, 4);
	if ($type eq 's') {
	    $self->add_file($type, $file, source => $pkg, version => $ver);
	} else {
	    $self->add_file($type, $file, package => $pkg, version => $ver);
	}
    }
    close(IN);
}

# for each package (the sort is to make sure that source packages are
# before the corresponding binary packages--this has the advantage that binary
# can use information from the source packages if these are unpacked)
my %type_sort = ('b' => 1, 'u' => 1, 's' => 2 );
sub get_all {
    return sort({$type_sort{$b->{type}} <=> $type_sort{$a->{type}}}
		@{$_[0]->{schedule}});
}

sub count {
    return scalar @{$_[0]->{schedule}};
}

1;

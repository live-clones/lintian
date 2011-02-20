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

## Represents something Lintian can process (e.g. a deb, dsc or a changes)
package Lintian::Processable;

use base qw(Class::Accessor);

use strict;
use warnings;

use Util;

sub new {
    my ($class, $pkg_type, $pkg_path) = @_;
    my $self = {};
    bless $self, $class;
    $self->{pkg_type} = $pkg_type;
    $self->{pkg_path} = $pkg_path;
    $self->_init ($pkg_type, $pkg_path);
    return $self;
}

Lintian::Processable->mk_accessors (qw(pkg_name pkg_version pkg_src pkg_arch pkg_path pkg_type group));


sub set_group{
    my ($self, $group) = @_;
    $self->{group} = $group;
    return 1;
}

sub _init{
    my ($self, $pkg_type, $pkg_path) = @_;
    if ($pkg_type eq 'binary' or $pkg_type eq 'udeb'){
        my $dinfo = get_deb_info ($pkg_path) or
            fail "could not read control data in $pkg_path: $!";
        my $pkg_name = $dinfo->{package} or
            fail "$pkg_path ($pkg_type) is missing mandatory \"Package\" field";
        my $pkg_src = $dinfo->{source};
        # Source may be left out if it is the same as $pkg_name
        $pkg_src = $pkg_name unless ( defined $pkg_src && length $pkg_src );

        # Source may contain the version (in parentheses)
        $pkg_src =~ s/\s*\(.+$//o;
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $dinfo->{version};
        $self->{pkg_arch} = $dinfo->{architecture};
        $self->{pkg_src} = $pkg_src;
    } elsif ($pkg_type eq 'source'){
        my $dinfo = get_dsc_info ($pkg_path) or fail "$pkg_path is not valid dsc file";
        my $pkg_name = $dinfo->{source} or fail "$pkg_path is missing or has empty source field";
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $dinfo->{version};
        $self->{pkg_arch} = 'source';
        $self->{pkg_src} = $pkg_name; # it is own source pkg
    } elsif ($pkg_type eq 'changes'){
        my $cinfo = get_dsc_info ($pkg_path) or fail "$pkg_path is not a valid changes file";
        my $pkg_name = $pkg_path;
        $pkg_name =~ s,.*/([^/]+)\.changes$,$1,;
        $self->{pkg_name} = $pkg_name;
        $self->{pkg_version} = $cinfo->{version};
        $self->{pkg_src} = $cinfo->{source}//$pkg_name;
        $self->{pkg_arch} = $cinfo->{architecture};
    } else {
        fail "Unknown package type $pkg_type";
    }
    # make sure these are not undefined
    $self->{pkg_version} = '' unless (defined $self->{pkg_version});
    $self->{pkg_arch}    = '' unless (defined $self->{pkg_arch});
    return 1;
}

1;

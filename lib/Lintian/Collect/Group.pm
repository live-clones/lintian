# -*- perl -*-
# Lintian::Collect::Group -- interface to group data collections

# Copyright (C) 2008 Russ Allbery
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

# This is a "Lintian::Collect"-like interace (as in "not quite a
# Lintian::Collect").
package Lintian::Collect::Group;
use strict;
use warnings;

use Carp qw(croak);

sub new {
    my ($class, $group) = @_;
    my $self = {
        'group' => $group,
    };
    return bless $self, $class;
}

# Returns the direct strong dependendencies for a package
# that are available in the group.
# (strong dependencies are "Depends" and "Pre-Depends")
#
# Note: "Self-dependencies" (if any) are *not* included.
#
# sub direct_dependencies Needs-Info <>
sub direct_dependencies {
    my ($self, $p) = @_;
    my $deps = $self->{'direct-dependencies'};
    unless ($deps) {
        my $group = $self->{'group'};
        my @procs = $group->get_processables ('binary');
        push @procs, $group->get_processables ('udeb');
        $deps = {};
        foreach my $proc (@procs) {
            my $pname = $proc->pkg_name;
            my $relation = $proc->info->relation('strong');
            my $d = [];
            foreach my $oproc (@procs) {
                my $opname = $oproc->pkg_name;
                # Ignore self deps - we have checks for that and it
                # will just end up complicating "correctness" of
                # otherwise simple checks.
                next if $opname eq $pname;
                push @$d, $oproc if $relation->implies($opname);
            }
            $deps->{$pname} = $d;
        }
        $self->{'direct-dependencies'} = $deps;
    }
    return $deps->{$p->pkg_name} if $p;
    return $deps;
}

# Return the package type.
# sub type Needs-Info <>
sub type {
    my ($self) = @_;
    return 'group';
}

1;
__END__;


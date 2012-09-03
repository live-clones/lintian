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

## Represents a pool of processables (Lintian::Processable)
package Lintian::ProcessablePool;

use strict;
use warnings;

use Carp qw(croak);

use Cwd();
use Lintian::Util;

use Lintian::Processable::Package;
use Lintian::ProcessableGroup;

=head1 NAME

Lintian::ProcessablePool -- Pool of processables

=head1 SYNOPSIS

 use Lintian::ProcessablePool;
 
 my $pool = Lintian::ProcessablePool->new();
 $pool->add_file('foo.changes');
 $pool->add_file('bar.dsc');
 $pool->add_file('baz.deb');
 foreach my $gname ($pool->get_group_names()){
    my $group = $pool->get_group($gname);
    process($gname, $group);
 }

=head1 METHODS

=over 4

=item Lintian::ProcessablePool->new

Creates a new empty pool.

=cut

sub new {
    my ($class) = @_;
    my $self = {};
    foreach my $field (qw(binary changes groups source udeb)){
        $self->{$field} = {};
    }
    bless $self, $class;
    return $self;
}

=item $pool->add_file($file)

Adds a file to the pool.  The $file will be turned into a
L<processable|Lintian::Processable> and grouped together with other
processables from the same source package (if any).

=cut

sub add_file {
    my ($self, $file) = @_;
    if ($file =~ m/\.changes$/o){
        croak "$file does not exist" unless -f $file;
        my $pkg_path = Cwd::abs_path ($file);
        croak "Cannot resolve $file: $!" unless $pkg_path;
        return $self->_add_changes_file ($pkg_path);
    }

    my $proc = Lintian::Processable::Package->new ($file);
    return $self->add_proc ($proc);
}

=item $pool->add_proc ($proc)

Adds a L<processable|Lintian::Processable> to the pool.

=cut

sub add_proc {
    my ($self, $proc) = @_;
    my $procid;
    my ($group, $groupid);
    my $pkg_type = $proc->pkg_type;
    my $tmap = $self->{$pkg_type};


   if ($proc->tainted) {
        warn (sprintf ("warning: tainted %1\$s package '%2\$s', skipping\n",
             $pkg_type, $proc->pkg_name));
        return 0;
    }
    $procid = $self->_get_proc_id ($proc);
    return 0 if exists $tmap->{$procid};
    $groupid = $self->_get_group_id ($proc);
    $group = $self->{groups}->{$groupid};
    if (defined $group){
        if ($pkg_type eq 'source'){
            # if this is a source pkg, then this is a duplicate
            # assuming the group already has a source package.
            return 0 if defined $group->get_source_processable;
        }
        # else add the binary/udeb proc to the group
        return $group->add_processable ($proc);
    } else {
        # Create a new group
        $group = Lintian::ProcessableGroup->new;
        $group->add_processable($proc);
        $self->{groups}->{$groupid} = $group;
    }
    # add it to the "unprocessed"/"seen" map.
    $tmap->{$procid} = $proc;
    return 1;
}

=item $pool->get_group_names()

Returns the name of all the groups in this pool.

Do not modify the list nor its contents.

=cut

sub get_group_names{
    my ($self) = @_;
    return keys %{ $self->{groups} };
}

=item $pool->get_group($name)

Returns the group called $name or C<undef>
if there is no group called $name.

=cut

sub get_group{
    my ($self, $group) = @_;
    return $self->{groups}->{$group};
}

=item $pool->get_groups()

Returns all the groups in the pool.

Do not modify the list nor its contents.

=cut

sub get_groups{
    my ($self) = @_;
    my $groups = $self->{groups};
    if (scalar keys %$groups) {
        return values %$groups;
    }
    return ();
}

=item $pool->empty()

Returns true if the pool is empty.

=cut

sub empty{
    my ($self) = @_;
    return scalar keys %{ $self->{groups} } < 1;
}

#### Internal subs ####

sub _add_changes_file{
    my ($self, $pkg_path) = @_;
    my $group = Lintian::ProcessableGroup->new($pkg_path);
    my $cproc = $group->get_changes_processable();
    my $gid = $self->_get_group_id($cproc);
    my $ogroup = $self->{groups}->{$gid};
    if (defined($ogroup)){
        # Group already exists...
        my $tmap = $self->{'changes'};
        my $cid = $self->_get_proc_id($cproc);
        my $added = 0;
        # duplicate changes file?
        return 0 if (exists $tmap->{$cid});
        # Merge architectures/packages ...
        # Accept all new
        if (! defined $ogroup->get_source_processable()
            && defined $group->get_source_processable()){
                $ogroup->add_processable($group->get_source_processable());
                $added = 1;
        }
        foreach my $bin ($group->get_binary_processables()){
            my $tbmap = $self->{$bin->pkg_type()};
            my $procid = $self->_get_proc_id($bin);
            if (! exists $tbmap->{$procid}){
                # New binary package
                $tbmap->{$procid} = $bin;
                $ogroup->add_processable($bin);
                $added = 1;
            }
        }
        return $added;
    } else {
        $self->{groups}->{$gid} = $group;
    }
    return 1;
}

# Fetches the group id for a package
#  - this id is based on the name and the version of the
#    src-pkg.
sub _get_group_id{
    my ($self, $pkg) = @_;
    my $id = $pkg->pkg_src;
    $id .= '/' . $pkg->pkg_src_version;
    return $id;
}

# Fetches the id of the processable; note this is different
# than _get_group_id even for src processables.
sub _get_proc_id {
    my ($self, $pkg) = @_;
    return $pkg->identifier;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable>

L<Lintian::ProcessableGroup>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

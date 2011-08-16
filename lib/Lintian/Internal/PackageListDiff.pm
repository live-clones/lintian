# Lintian::Internal::PackageListDiff -- Representation of a diff between two PackageLists

# Copyright (C) 2011 Niels Thykier
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

package Lintian::Internal::PackageListDiff;

use strict;
use warnings;

use base qw(Class::Accessor);

=head1 NAME

Lintian::Inernal::PackageListDiff -- Difference representation between two PackageLists

=head1 SYNOPSIS

 use Lintian::Internal::PackageList;
 
 my $olist = Lintian::Internal::PackageList->new('binary');
 my $nlist = Lintian::Internal::PackageList->new('binary');
 $olist->read_list('old/binary-packages');
 $nlist->read_list('new/binary-packages');
 my $diff = $nlist->diff($olist);
 foreach my $added (@{ $diff->added }) {
    my $entry = $nlist->get($added);
    # do something
 }
 foreach my $removed (@{ $diff->removed }) {
    my $entry = $olist->get($removed);
    # do something
 }
 foreach my $changed (@{ $diff->changed }) {
    my $oentry = $olist->get($changed);
    my $nentry = $nlist->get($changed);
    # use/diff $oentry and $nentry as needed
 }

=head1 DESCRIPTION

Instances of this class provides access to the packages list used by
the Lab as caches.

=head1 METHODS

=over 4

=cut

# Private constructor (used by Lintian::Internal::PackageList
sub _new {
    my ($class, $type, $nlist, $olist, $added, $removed, $changed) = @_;
    my $self = {
        'added'   => $added,
        'removed' => $removed,
        'changed' => $changed,
        'type'    => $type,
        'olist'   => $olist,
        'nlist'   => $nlist,
    };
    bless $self, $class;
    return $self;
}

=item $diff->added

Returns a list ref containing the names of the elements that has been added.

=item $diff->removed

Returns a list ref containing the names of the elements that has been removed.

=item $diff->changed

Returns a list ref containing the names of the elements that has been changed.

=item $diff->nlist

Returns the "new" list used to create this diff.  Note the list is not
copied and may have been changed since the diff has been created.

=item $diff->olist

Returns the "old" list used to create this diff.  Note the list is not
copied and may have been changed since the diff has been created.

=cut

Lintian::Internal::PackageListDiff->mk_ro_accessors (qw(added removed changed type nlist olist));

1;


# -*- perl -*-
# Lintian::Collect -- interface to package data collection

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

package Lintian::Collect;
use strict;
use Util qw(fail);

# Take the package name and type, initialize an appropriate collect object
# based on the package type, and return it.  fail with unknown types,
# since we do not check in other packes if this returns a value.
sub new {
    my ($class, $pkg, $type) = @_;
    my $object;
    if ($type eq 'source') {
        require Lintian::Collect::Source;
        $object = Lintian::Collect::Source->new ($pkg);
    } elsif ($type eq 'binary' or $type eq 'udeb') {
        require Lintian::Collect::Binary;
        $object = Lintian::Collect::Binary->new ($pkg);
    } elsif ($type eq 'changes') {
	require Lintian::Collect::Changes;
	$object = Lintian::Collect::Changes->new ($pkg);
    } else {
        fail("Undefined type: $type");
    }
    $object->{name} = $pkg;
    $object->{type} = $type;
    return $object;
}

# Return the package name.
# sub name Needs-Info <>
sub name {
    my ($self) = @_;
    return $self->{name};
}

# Return the package type.
# sub type Needs-Info <>
sub type {
    my ($self) = @_;
    return $self->{type};
}

# Return the value of the specified control field of the package, or undef if
# that field wasn't present in the control file for the package.  For source
# packages, this is the *.dsc file; for binary packages, this is the control
# file in the control section of the package.  For .changes files, the 
# information will be retrieved from the file itself.
# sub field Needs-Info <>
sub field {
    my ($self, $field) = @_;
    return $self->{field}{$field} if exists $self->{field}{$field};
    if (open(FIELD, '<', "fields/$field")) {
        local $/;
        my $value = <FIELD>;
        close FIELD;
        $value =~ s/\n\z//;
        $self->{field}{$field} = $value;
    } else {
        $self->{field}{$field} = undef;
    }
    return $self->{field}{$field};
}

=head1 NAME

Lintian::Collect - Lintian interface to package data collection

=head1 SYNOPSIS

    my ($name, $type) = ('foobar', 'udeb');
    my $collect = Lintian::Collect->new($name, $type);
    $name = $collect->name;
    $type = $collect->type;

=head1 DESCRIPTION

Lintian::Collect provides the shared interface to package data used by
source, binary and udeb packages and .changes files.  It creates an 
object of the appropriate type and provides common functions used by the 
collection interface to all types of package.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data via
this module and its subclasses so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 CLASS METHODS

=over 4

=item new(PACKAGE, TYPE)

Creates a new object appropriate to the package type.  TYPE can be 
retrieved later with the type() method.  Returns undef an unknown TYPE.

PACKAGE is the name of the package and is stored in the collect object.
It can be retrieved with the name() method.

=back

=head1 INSTANCE METHODS

In addition to the instance methods documented here, see the documentation
of Lintian::Collect::Source, Lintian::Collect::Binary and 
Lintian::Collect::Changes for instance methods specific to source and 
binary / udeb packages and .changes files.

=over 4

=item field(FIELD)

Returns the value of the control field FIELD in the control file for the
package.  For a source package, this is the *.dsc file; for a binary
package, this is the control file in the control section of the package.
The value will be read from the F<fields/> subdirectory of the current
directory if it hasn't previously been requested and cached in memory so
that subsequent requests for the same field can be answered without file
accesses.

=item name()

Returns the name of the package.

=item type()

Returns the type of the package.

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect::Binary(3), Lintian::Collect::Changes(3),
Lintian::Collect::Source(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround

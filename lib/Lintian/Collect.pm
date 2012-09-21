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
use warnings;

use Lintian::Util qw(get_dsc_info get_deb_info);
use Carp qw(croak);

# Take the package name and type, initialize an appropriate collect object
# based on the package type, and return it.  fail with unknown types,
# since we do not check in other packes if this returns a value.
sub new {
    my ($class, $pkg, $type, $base_dir, $fields) = @_;
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
        croak("Undefined type: $type");
    }
    $object->{name} = $pkg;
    $object->{type} = $type;
    $object->{base_dir} = $base_dir;
    $object->{field} = $fields if defined $fields;
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

# Return the base dir of the package's lab.
# sub base_dir Needs-Info <>
sub base_dir {
    my ($self) = @_;
    return $self->{base_dir};
}

# Return the path to a file (or dir) in the lab
# - convenience around base_dir
# sub lab_data_path Needs-Info <>
sub lab_data_path {
    my ($self, $entry) = @_;
    my $base = $self->base_dir;
    return "$base/$entry" if $entry;
    return $base;
}

# Return the value of the specified control field of the package, or undef if
# that field wasn't present in the control file for the package.  For source
# packages, this is the *.dsc file; for binary packages, this is the control
# file in the control section of the package.  For .changes files, the 
# information will be retrieved from the file itself.
# sub field Needs-Info <>
sub field {
    my ($self, $field, $def) = @_;
    return $self->_get_field ($field, $def);
}

# $self->_get_field([$name[, $def]])
#
# Method getting the fields; this is the backing method of $self->field
#
# It must return either a field (if $name is given) or a hash, where the keys are
# the name of the fields.  If $name is given and it is not present, then it will
# return $def (or undef if $def was not given).
#
# It must cache the result if possible, since field and fields are called often.
# sub _get_field Needs-Info <>
sub _get_field {
    my ($self, $field, $def) = @_;
    my $fields;
    unless (exists $self->{field}) {
        my $base_dir = $self->base_dir();
        my $type = $self->{type};
        if ($type eq 'changes' or $type eq 'source'){
            my $file = 'changes';
            $file = 'dsc' if $type eq 'source';
            $fields = get_dsc_info("$base_dir/$file");
        } elsif ($type eq 'binary' or $type eq 'udeb'){
            # (ab)use the unpacked control dir if it is present
            if ( -f "$base_dir/control/control" && -s "$base_dir/control/control") {
                $fields = get_dsc_info("$base_dir/control/control");
            } else {
                $fields = (get_deb_info("$base_dir/deb"));
            }
            $fields->{'source'} = $fields->{'package'} unless $fields->{'source'};
        }
        $self->{field} = $fields;
    } else {
        $fields = $self->{field};
    }
    return $fields->{$field}//$def if $field;
    return $fields;
}

=head1 NAME

Lintian::Collect - Lintian interface to package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'udeb', '/some/abs/path');
    my $collect = Lintian::Collect->new ($name, $type, $dir);
    $name = $collect->name;
    $type = $collect->type;

=head1 DESCRIPTION

Lintian::Collect provides the shared interface to package data used by
source, binary and udeb packages and .changes files.  It creates an 
object of the appropriate type and provides common functions used by the 
collection interface to all types of package.

Usually instances should not be created directly (exceptions include
collections), but instead be requested via the
L<info|Lintian::Lab::Entry/info> method in Lintian::Lab::Entry.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data via
this module and its subclasses so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 CLASS METHODS

=over 4

=item new(PACKAGE, TYPE, BASEDIR[, FIELDS])

Creates a new object appropriate to the package type.  TYPE can be
retrieved later with the type() method.  Croaks if given an unknown
TYPE.

PACKAGE is the name of the package and is stored in the collect object.
It can be retrieved with the name() method.

BASEDIR is the base directory for the data and should be absolute.

If FIELDS is given it is assumed to be the fields from the underlying
control file.  This is only used to avoid an unnecessary read
operation (possibly incl. an ar | gzip pipeline) when the fields are
already known.

=back

=head1 INSTANCE METHODS

In addition to the instance methods documented here, see the documentation
of Lintian::Collect::Source, Lintian::Collect::Binary and 
Lintian::Collect::Changes for instance methods specific to source and 
binary / udeb packages and .changes files.

=over 4

=item field([FIELD[, DEFAULT]])

If FIELD is given, this method returns the value of the control field
FIELD in the control file for the package.  For a source package, this
is the *.dsc file; for a binary package, this is the control file in
the control section of the package.

If FIELD is passed but not present, then this method will return
DEFAULT (if given) or undef.

Otherwise this will return a hash of fields, where the key is the field
name (in all lowercase).

Note: For binary and udeb packages, this method will create the
"source"-field if it does not exist (using the value of the
"package"-field as described in §5.6.1 of the Debian Policy Manual).

Some checks rely on the presence "source"-field to whitelist some
packages, so removing this behaviour may cause regressions (see
bug 640186 for an example).

=item name()

Returns the name of the package.

=item type()

Returns the type of the package.

=item base_dir()

Returns the base_dir where all the package information is stored.

=item lab_data_path ([ENTRY])

Return the path to the ENTRY in the lab.  This is a convenience method
around base_dir.  If ENTRY is not given, this method behaves like
base_dir.

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
# vim: syntax=perl sw=4 sts=4 sr et

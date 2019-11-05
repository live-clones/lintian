# -*- perl -*-  Lintian::Collect::Dispatcher -- type neutral dispatcher
#
# Copyright (C) 2019 Felix Lechner
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

package Lintian::Collect::Dispatcher;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(create_info);

use Carp qw(croak);

=encoding utf-8

=head1 NAME

Lintian::Collect::Dispatcher - type neutral dispatcher

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'udeb', '/some/abs/path');
    my $collect = create_info($name, $type, $dir);
    $name = $collect->name;
    $type = $collect->type;

=head1 DESCRIPTION

Lintian::Processable provides the shared interface to package data used by
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

=item create_info (PACKAGE, TYPE, BASEDIR[, FIELDS]))

Creates a new object appropriate to the package type.  TYPE can be
retrieved later with the L</type> method.  Croaks if given an unknown
TYPE.

PACKAGE is the name of the package and is stored in the collect object.
It can be retrieved with the L</name> method.

BASEDIR is the base directory for the data and should be absolute.

If FIELDS is given it is assumed to be the fields from the underlying
control file.  This is only used to avoid an unnecessary read
operation (possibly incl. an ar | gzip pipeline) when the fields are
already known.

Needs-Info requirements for using I<create_info>: none

=cut

sub create_info {
    my ($pkg, $type, $base_dir, $fields) = @_;

    my $object;

    if ($type eq 'source') {
        require Lintian::Processable::Source;
        $object = Lintian::Processable::Source->new;

    } elsif ($type eq 'binary' or $type eq 'udeb') {
        require Lintian::Processable::Binary;
        $object = Lintian::Processable::Binary->new;

    } elsif ($type eq 'buildinfo') {
        require Lintian::Processable::Buildinfo;
        $object = Lintian::Processable::Buildinfo->new;

    } elsif ($type eq 'changes') {
        require Lintian::Processable::Changes;
        $object = Lintian::Processable::Changes->new;

    } else {
        croak("Undefined type: $type");
    }

    $object->name($pkg);
    $object->type($type);
    $object->base_dir($base_dir);

    $object->verbatim($fields)
      if defined $fields;

    return $object;
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Processable::Binary>, L<Lintian::Processable::Changes>,
L<Lintian::Processable::Source>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

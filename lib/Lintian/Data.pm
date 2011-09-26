# -*- perl -*-
# Lintian::Data -- interface to query lists of keywords

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

package Lintian::Data;
use strict;
use warnings;

use Carp qw(croak);

# The constructor loads a list into a hash in %data, which is private to this
# module.  Use %data as a cache to avoid loading the same list more than once
# (which means lintian doesn't support having the list change over the life of
# the proces.  The returned object knows what list, stored in %data, it is
# supposed to act on.
{
    my %data;
    sub new {
        my ($class, $type, $separator, $code) = @_;
        croak('no data type specified') unless $type;
        unless (exists $data{$type}) {
            my $dir = $ENV{LINTIAN_ROOT} . '/data';
            open(LIST, '<', "$dir/$type")
                or croak("unknown data type $type");
            local ($_, $.);
            while (<LIST>) {
                chomp;
                s/^\s+//;
                next if /^\#/;
                next if $_ eq '';
                my ($key, $val);
                if (defined $separator) {
                    ($key, $val) = split(/$separator/, $_, 2);
                    $val = $code->($key, $val) if $code;
                } else {
                    ($key, $val) = ($_ => 1);
                }
                $data{$type}{$key} = $val;
            }
        }
        my $self = { data => $data{$type} };
        bless($self, $class);
        return $self;
    }
}

# Query a data object for whether a particular keyword is valid.
sub known {
    my ($self, $keyword) = @_;
    return (exists $self->{data}{$keyword}) ? 1 : undef;
}

# Return all known keywords (in no particular order).
sub all {
    my ($self) = @_;
    return keys(%{ $self->{data} });
}

# Query a data object for the value attached to a particular keyword.
sub value {
    my ($self, $keyword) = @_;
    return (exists $self->{data}{$keyword}) ? $self->{data}{$keyword} : undef;
}

1;

=head1 NAME

Lintian::Data - Lintian interface to query lists of keywords

=head1 SYNOPSIS

    my $keyword;
    my $list = Lintian::Data->new('type');
    if ($list->known($keyword)) {
        # do something ...
    }
    my $hash = Lintian::Data->new('another-type', '\s+');
    if ($list->value($keyword) > 1) {
        # do something ...
    }
    my @keywords = $list->all;

=head1 DESCRIPTION

Lintian::Data provides a way of loading a list of keywords or key/value
pairs from a file in the Lintian root and then querying that list.
The lists are stored in the F<data> directory of the Lintian root and
consist of one keyword or key/value pair per line.  Blank lines and
lines beginning with C<#> are ignored.  Leading and trailing whitespace
is stripped.

If requested, the lines are split into key/value pairs with a given
separator regular expression.  Otherwise, keywords are taken verbatim
as they are listed in the file and may include spaces.

This module allows lists such as menu sections, doc-base sections,
obsolete packages, package fields, and so forth to be stored in simple,
easily editable files.

=head1 CLASS METHODS

=over 4

=item new(TYPE [,SEPARATOR[, CODE]])

Creates a new Lintian::Data object for the given TYPE.  TYPE is a partial
path relative to the F<data> directory and should correspond to a file in
that directory.  The contents of that file will be loaded into memory and
returned as part of the newly created object.  On error, new() throws an
exception.

If SEPARATOR is given, it will be used as a regular expression for splitting
the lines into key/value pairs.

If CODE is also given, it is assumed to be a sub that will pre-process
the key/value pairs.  The sub will be called once for each key/pair
value with the key as the first and the value as the second argument.
The value returned is will be used as the value for the key.

A given file will only be loaded once.  If new() is called again with the
same TYPE argument, the data previously loaded will be reused, avoiding
multiple file reads.

=back

=head1 INSTANCE METHODS

=over 4

=item all()

Returns all keywords listed in the data file as a list (in no particular
order; the original order is not preserved).  In a scalar context, returns
the number of keywords.

=item known(KEYWORD)

Returns true if KEYWORD was listed in the data file represented by this
Lintian::Data instance and false otherwise.

=item value(KEYWORD)

Returns the value attached to KEYWORD if it was listed in the data
file represented by this Lintian::Data instance and the undefined value
otherwise. If SEPARATOR was not given, the value will '1'.

=back

=head1 DIAGNOSTICS

=over 4

=item no data type specified

new() was called without a TYPE argument.

=item unknown data type %s

The TYPE argument to new() did not correspond to a file in the F<data>
directory of the Lintian root.

=back

=head1 FILES

=over 4

=item LINTIAN_ROOT/data

The files loaded by this module must be located in this directory.
Relative paths containing a C</> are permitted, so files may be organized
in subdirectories in this directory.

=back

=head1 ENVIRONMENT

=over 4

=item LINTIAN_ROOT

This variable must be set to Lintian's root directory (normally
F</usr/share/lintian> when Lintian is installed as a Debian package).  The
B<lintian> program normally takes care of doing this.  This module doesn't
care about the contents of this directory other than expecting the F<data>
subdirectory of this directory to contain its files.

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

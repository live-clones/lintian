# fields/unknown -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Fields::Unknown;

use v5.20;
use warnings;
use utf8;

use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Whitelist of XS-* source fields
my %source_field_whitelist = (
    'Autobuild'      => 1,
    'Go-Import-Path' => 1,
    'Ruby-Versions'  => 1,
);

sub source {
    my ($self) = @_;

    my $KNOWN_SOURCE_FIELDS= $self->data->load('common/source-fields');
    my @unknown= $self->processable->fields->extra($KNOWN_SOURCE_FIELDS->all);

    # The grep filter is a workaround for #1014885 and #1029471
    $self->hint('unknown-field', $_)
      for grep { !exists($source_field_whitelist{$_}) } @unknown;

    return;
}

sub binary {
    my ($self) = @_;

    my $KNOWN_BINARY_FIELDS= $self->data->load('fields/binary-fields');
    my @unknown= $self->processable->fields->extra($KNOWN_BINARY_FIELDS->all);

    $self->hint('unknown-field', $_)for @unknown;

    return;
}

sub udeb {
    my ($self) = @_;

    my $KNOWN_UDEB_FIELDS = $self->data->load('fields/udeb-fields');
    my @unknown = $self->processable->fields->extra($KNOWN_UDEB_FIELDS->all);

    $self->hint('unknown-field', $_)for @unknown;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# fields/unknown -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::fields::unknown;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use Path::Tiny;

use Lintian::Data ();

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $KNOWN_SOURCE_FIELDS = Lintian::Data->new('common/source-fields');
our $KNOWN_BINARY_FIELDS = Lintian::Data->new('fields/binary-fields');
our $KNOWN_UDEB_FIELDS = Lintian::Data->new('fields/udeb-fields');

sub source {
    my ($self) = @_;

    my @unknown= $self->find_missing([keys %{$self->processable->field}],
        [$KNOWN_SOURCE_FIELDS->all]);

    my $dscfile = path($self->processable->path)->basename;
    $self->tag('unknown-field', $dscfile, $_)for @unknown;

    return;
}

sub binary {
    my ($self) = @_;

    my @unknown= $self->find_missing([keys %{$self->processable->field}],
        [$KNOWN_BINARY_FIELDS->all]);

    my $debfile = path($self->processable->path)->basename;
    $self->tag('unknown-field', $debfile, $_)for @unknown;

    return;
}

sub udeb {
    my ($self) = @_;

    my @unknown= $self->find_missing([keys %{$self->processable->field}],
        [$KNOWN_UDEB_FIELDS->all]);

    my $udebfile = path($self->processable->path)->basename;
    $self->tag('unknown-field', $udebfile, $_)for @unknown;

    return;
}

sub find_missing {
    my ($self, $required, $actual) = @_;

    my %required_lookup = map { lc $_ => $_ } @{$required};
    my @actual_lowercase = map { lc } @{$actual};

    # select fields for announcement
    my $missinglc
      = List::Compare->new([keys %required_lookup], \@actual_lowercase);
    my @missing_lowercase = $missinglc->get_Lonly;

    my @missing = map { $required_lookup{$_} } @missing_lowercase;

    return @missing;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

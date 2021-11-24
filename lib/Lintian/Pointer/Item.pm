# Copyright © 2021 Felix Lechner <felix.lechner@lease-up.com>
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

package Lintian::Pointer::Item;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

const my $EMPTY => q{};
const my $COLON => q{:};

=head1 NAME

Lintian::Pointer::Item -- Facilities for pointing into specific index items

=head1 SYNOPSIS

use Lintian::Pointer::Item;

=head1 DESCRIPTION

A class for item pointers

=head1 INSTANCE METHODS

=over 4

=item item

=item position

=cut

has item => (is => 'rw');
has position => (is => 'rw', default => $EMPTY);

=item to_string

=cut

sub to_string {
    my ($self) = @_;

    croak encode_utf8('No item')
      unless defined $self->item;

    my $text = $self->item->name;

    $text .= $COLON . $self->position
      if length $self->position;

    return $text;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

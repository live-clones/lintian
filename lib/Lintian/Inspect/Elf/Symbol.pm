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

package Lintian::Inspect::Elf::Symbol;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $EMPTY => q{};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Inspect::Elf::Symbol -- ELF Symbols

=head1 SYNOPSIS

 use Lintian::Inspect::Elf::Symbol;

=head1 DESCRIPTION

A class for storing ELF symbol data

=head1 INSTANCE METHODS

=over 4

=item name

=item version

=item section

=cut

has name => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);
has version => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);
has section => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);

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

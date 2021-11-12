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

package Lintian::Inspect::Elf::Section;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $EMPTY => q{};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Inspect::Elf::Section -- ELF Sections

=head1 SYNOPSIS

 use Lintian::Inspect::Elf::Section;

=head1 DESCRIPTION

A class for storing ELF section data

=head1 INSTANCE METHODS

=over 4

=item number

=item name

=item type

=item address

=item offset

=item size

=item entry_size

=item flags

=item index_link

=item index_info

=item alignment

=cut

has number => (
    is => 'rw',
    coerce => sub { my ($number) = @_; return ($number // 0); },
    default => 0
);

has name => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);

has type => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);

has address => (
    is => 'rw',
    coerce => sub { my ($number) = @_; return ($number // 0); },
    default => 0
);

has offset => (
    is => 'rw',
    coerce => sub { my ($number) = @_; return ($number // 0); },
    default => 0
);

has size => (
    is => 'rw',
    coerce => sub { my ($number) = @_; return ($number // 0); },
    default => 0
);

has entry_size => (
    is => 'rw',
    coerce => sub { my ($number) = @_; return ($number // 0); },
    default => 0
);

has flags => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);

has index_link => (
    is => 'rw',
    coerce => sub { my ($number) = @_; return ($number // 0); },
    default => 0
);

has index_info => (
    is => 'rw',
    coerce => sub { my ($number) = @_; return ($number // 0); },
    default => 0
);

has alignment => (
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

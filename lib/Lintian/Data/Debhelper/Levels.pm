# -*- perl -*-
#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2009 Russ Allbery
# Copyright © 2020 Felix Lechner
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

package Lintian::Data::Debhelper::Levels;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Data';

=head1 NAME

Lintian::Data::Debhelper::Levels - Lintian interface for debhelper
compat levels.

=head1 SYNOPSIS

    use Lintian::Data::Debhelper::Levels;

=head1 DESCRIPTION

This module provides a way to load data files for debhelper.

=head1 INSTANCE METHODS

=over 4

=item location

=item separator

=item accumulator

=cut

has location => (
    is => 'rw',
    default => 'debhelper/compat-level'
);

has separator => (
    is => 'rw',
    default => sub { qr/=/ });

has accumulator => (is => 'rw');

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

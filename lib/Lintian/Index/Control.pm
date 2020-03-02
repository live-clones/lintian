# -*- perl -*- Lintian::Index::Control
#
# Copyright © 2020 Felix Lechner
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

package Lintian::Index::Control;

use strict;
use warnings;

use Moo;
use namespace::clean;

with 'Lintian::Index';

=encoding utf-8

=head1 NAME

Lintian::Index::Control -- An index of a control file set

=head1 SYNOPSIS

 use Lintian::Index::Control;

 # Instantiate via Lintian::Index::Control
 my $orig = Lintian::Index::Control->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
control file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4



=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.
Substantial portions adapted from code written by Russ Allbery, Niels Thykier, and others.

=head1 SEE ALSO

lintian(1)

L<Lintian::Index>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

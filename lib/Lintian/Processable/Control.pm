# -*- perl -*- Lintian::Processable::Control
#
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

package Lintian::Processable::Control;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Index::Control;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Control - access to collected control file data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Control provides an interface to control file data.

=head1 INSTANCE METHODS

=over 4

=item control

Returns the index for a binary control file.

=cut

has control => (
    is => 'rw',
    lazy => 1,
    default => sub {
        return Lintian::Index::Control->new;
    });

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

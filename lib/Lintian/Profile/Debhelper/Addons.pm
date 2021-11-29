# -*- perl -*-
#
# Copyright © 2021 Felix Lechner
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

package Lintian::Profile::Debhelper::Addons;

use v5.20;
use warnings;
use utf8;

use Lintian::Data::Debhelper::Addons;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Profile::Debhelper::Addons - Lintian interface to Debhelper addons

=head1 SYNOPSIS

    my $profile = Lintian::Profile->new;

=head1 DESCRIPTION

Lintian::Profile::Debhelper::Addons provides an interface to Debhelper addons.

=head1 INSTANCE METHODS

=over 4

=item debhelper_addons

=cut

has debhelper_addons => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $addons = Lintian::Data::Debhelper::Addons->new;
        $addons->load($self->data_paths, $self->our_vendor);

        return $addons;
    });

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
# -*- perl -*-
# Lintian::Profile::Authority::VimPolicy

# Copyright © 2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#b
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Profile::Authority::VimPolicy;

use v5.20;
use warnings;
use utf8;

use Lintian::Data::Authority::VimPolicy;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Profile::Authority::VimPolicy - Lintian interface to manual references

=head1 SYNOPSIS

    my $profile = Lintian::Profile->new;

=head1 DESCRIPTION

Lintian::Profile::Authority::VimPolicy provides an interface to manual references.

=head1 INSTANCE METHODS

=over 4

=item vim_policy

=cut

has vim_policy => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::VimPolicy->new;
        $manual->load($self->data_paths, $self->our_vendor);

        return $manual;
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
# -*- perl -*-
# Lintian::Processable::Debian::Control -- interface to source package data collection

# Copyright © 2008 Russ Allbery
# Copyright © 2009 Raphael Geissert
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

package Lintian::Processable::Debian::Control;

use v5.20;
use warnings;
use utf8;

use Lintian::Debian::Control;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Debian::Control - Lintian interface to d/control fields

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Debian::Control provides an interface to package data
from d/control.

=head1 INSTANCE METHODS

=over 4

=item debian_control

=cut

has debian_control => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $control = Lintian::Debian::Control->new;

        my $file = $self->patched->resolve_path('debian/control');
        return $control
          unless defined $file;

        $control->load($file->unpacked_path);

        return $control;
    });

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.
Amended by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

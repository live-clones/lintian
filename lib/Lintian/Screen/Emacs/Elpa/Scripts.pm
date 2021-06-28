# Copyright © 2021 Felix Lechner
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

package Lintian::Screen::Emacs::Elpa::Scripts;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Screen';

=head1 NAME

Lintian::Screen::Emacs::Elpa::Scripts

=head1 SYNOPSIS

 use Moo;
 use namespace::clean;

=head1 DESCRIPTION

Screen out hints provoked by C<ELPA> packaging scripts.

=head1 INSTANCE METHODS

=over 4

=item suppress

=cut

sub suppress {
    my ($self, $processable, $context) = @_;

    return 1
      if $context =~ m{^usr/lib/emacsen-common/packages/}
      && ( $processable->type eq 'binary'
        || $processable->type eq 'udeb')
      && $processable->relation('strong')->implies('emacsen-common');

    return 0;
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

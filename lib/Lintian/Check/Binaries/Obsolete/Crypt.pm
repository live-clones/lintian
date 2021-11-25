# binaries/obsolete/crypt -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2012 Kees Cook
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Binaries::Obsolete::Crypt;

use v5.20;
use warnings;
use utf8;

use Lintian::Pointer::Item;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has OBSOLETE_CRYPT_FUNCTIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/obsolete-crypt-functions',
            qr/\s*\|\|\s*/);
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    my $pointer = Lintian::Pointer::Item->new;
    $pointer->item($item);

    for my $symbol (@{$item->elf->{SYMBOLS} // []}) {

        next
          unless $symbol->section eq 'UND';

        next
          unless $self->OBSOLETE_CRYPT_FUNCTIONS->recognizes($symbol->name);

        my $tag = $self->OBSOLETE_CRYPT_FUNCTIONS->value($symbol->name);

        $self->pointed_hint($tag, $pointer, $symbol->name);
    }

    for my $member_name (keys %{$item->elf_by_member}) {

        for
          my $symbol (@{$item->elf_by_member->{$member_name}{SYMBOLS} // []}) {

            next
              unless $symbol->section eq 'UND';

            next
              unless $self->OBSOLETE_CRYPT_FUNCTIONS->recognizes(
                $symbol->name);

            my $tag = $self->OBSOLETE_CRYPT_FUNCTIONS->value($symbol->name);

            $self->pointed_hint($tag, $pointer, "($member_name)",
                $symbol->name);
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

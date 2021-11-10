# binaries/large-file-support -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::LargeFileSupport;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has ARCH_REGEX => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/arch-regex', qr/\s*\~\~/,
            sub { return qr/$_[1]/ });
    });

has LFS_SYMBOLS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/lfs-symbols');
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # The LFS check only works reliably for ELF files due to the
    # architecture regex.
    return
      unless $item->is_elf;

    # Only 32bit ELF binaries can lack LFS.
    return
      unless $item->file_info =~ $self->ARCH_REGEX->value('32');

    return
      if $item->name =~ m{^usr/lib/debug/};

    my @unresolved_symbols;
    for my $symbol (@{$item->elf->{SYMBOLS} // [] }) {

        # ignore if defined in the binary
        next
          unless $symbol->section eq 'UND';

        push(@unresolved_symbols, $symbol->name);
    }

    # Using a 32bit only interface call, some parts of the
    # binary are built without LFS
    $self->hint('binary-file-built-without-LFS-support', $item->name)
      if any { $self->LFS_SYMBOLS->recognizes($_) } @unresolved_symbols;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

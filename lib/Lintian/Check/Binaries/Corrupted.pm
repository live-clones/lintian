# binaries/corrupted -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2012 Kees Cook
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Binaries::Corrupted;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    $self->check_elf_issues($item);

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    $self->check_elf_issues($item);

    return;
}

sub check_elf_issues {
    my ($self, $item) = @_;

    return unless $item->is_elf;

    for (uniq @{$item->elf->{ERRORS} // []}) {
        $self->pointed_hint('elf-error',$item->pointer, $_)
          unless (
            m{In program headers: Unable to find program interpreter name}
            and $item->name =~ m{^usr/lib/debug/});
    }

    $self->pointed_hint('elf-warning', $item->pointer, $_)
      for uniq @{$item->elf->{WARNINGS} // []};

    # static library
    for my $member_name (keys %{$item->elf_by_member}) {

        my $member_elf = $item->elf_by_member->{$member_name};

        $self->pointed_hint('elf-error', $item->pointer, $member_name, $_)
          for uniq @{$member_elf->{ERRORS} // []};

        $self->pointed_hint('elf-warning', $item->pointer, $member_name, $_)
          for uniq @{$member_elf->{WARNINGS} // []};
    }

    $self->pointed_hint('binary-with-bad-dynamic-table', $item->pointer)
      if $item->elf->{'BAD-DYNAMIC-TABLE'}
      && $item->name !~ m{^usr/lib/debug/};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

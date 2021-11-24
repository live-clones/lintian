# binaries/corrupted -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::Corrupted;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(uniq);

use Lintian::Pointer::Item;

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

    my $pointer = Lintian::Pointer::Item->new;
    $pointer->item($item);

    $self->pointed_hint('elf-error',$pointer, $_)
      for uniq @{$item->elf->{ERRORS} // []};

    $self->pointed_hint('elf-warning', $pointer, $_)
      for uniq @{$item->elf->{WARNINGS} // []};

    # static library
    for my $member_name (keys %{$item->elf_by_member}) {

        my $member_elf = $item->elf_by_member->{$member_name};

        $self->pointed_hint('elf-error', $pointer, $member_name, $_)
          for uniq @{$member_elf->{ERRORS} // []};

        $self->pointed_hint('elf-warning', $pointer, $member_name, $_)
          for uniq @{$member_elf->{WARNINGS} // []};
    }

    $self->pointed_hint('binary-with-bad-dynamic-table', $pointer)
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

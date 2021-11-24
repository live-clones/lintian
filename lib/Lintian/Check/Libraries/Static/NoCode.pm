# libraries/static/no-code -- lintian check script -*- perl -*-

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

package Lintian::Check::Libraries::Static::NoCode;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any uniq);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Pointer::Item;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # not sure if that captures everything GHC, or too much
    return
      if $item->name =~ m{^ usr/lib/ghc/ }x;

    return
      unless $item->file_info =~ m{ \b current [ ] ar [ ] archive \b }x;

    my @codeful_members;
    for my $member_name (keys %{$item->elf_by_member}) {

        my $member_elf = $item->elf_by_member->{$member_name};

        my @elf_sections = values %{$member_elf->{'SECTION-HEADERS'}};
        my @sections_with_size = grep { $_->size > 0 } @elf_sections;

        my @names_with_size = map { $_->name } @sections_with_size;

        my @KNOWN_ARRAY_SECTIONS = qw{.preinit_array .init_array .fini_array};
        my $lc_array
          = List::Compare->new(\@names_with_size, \@KNOWN_ARRAY_SECTIONS);

        my @have_array_sections = $lc_array->get_intersection;

# adapted from https://github.com/rpm-software-management/rpmlint/blob/main/rpmlint/checks/BinariesCheck.py#L242-L249
        my $has_code = 0;

        $has_code = 1
          if any { m{^ [.]text }x } @names_with_size;

        $has_code = 1
          if any { m{^ [.]data }x } @names_with_size;

        $has_code = 1
          if @have_array_sections;

        push(@codeful_members, $member_name)
          if $has_code;
    }

    my $pointer = Lintian::Pointer::Item->new;
    $pointer->item($item);

    $self->pointed_hint('no-code-sections', $pointer)
      unless @codeful_members;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# libraries/static/link-time-optimization -- lintian check script -*- perl -*-

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

package Lintian::Check::Libraries::Static::LinkTimeOptimization;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(uniq);

use Lintian::Pointer::Item;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # not sure if that captures everything GHC, or too much
    return
      if $item->name =~ m{^ usr/lib/ghc/ }x;

    return
      unless $item->file_info =~ m{ \b current [ ] ar [ ] archive \b }x;

    my $pointer = Lintian::Pointer::Item->new;
    $pointer->item($item);

    for my $member_name (keys %{$item->elf_by_member}) {

        my $member_elf = $item->elf_by_member->{$member_name};

        my @elf_sections = values %{$member_elf->{'SECTION-HEADERS'}};
        my @section_names = map { $_->name } @elf_sections;

        my @lto_section_names = grep { m{^ [.]gnu[.]lto }x } @section_names;

        $self->pointed_hint('static-link-time-optimization',
            $pointer, $member_name)
          if @lto_section_names;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

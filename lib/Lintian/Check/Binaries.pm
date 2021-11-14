# binaries -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries;

use v5.20;
use warnings;
use utf8;

use List::Compare;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    my @KNOWN_STRIPPED_SECTION_NAMES = qw{.note .comment};

    my @elf_sections = values %{$item->elf->{'SECTION-HEADERS'}};
    my @have_section_names = map { $_->name } @elf_sections;

    my $lc_name = List::Compare->new(\@have_section_names,
        \@KNOWN_STRIPPED_SECTION_NAMES);

    my @have_stripped_sections = $lc_name->get_intersection;

    # appropriately stripped, but is it stripped enough?
    if (   $item->file_info !~ m{ \b not [ ] stripped \b }x
        && $item->name !~ m{^ (?:usr/)? lib/ (?: debug | profile ) / }x) {

        $self->hint('binary-has-unneeded-section', $item->name, $_)
          for @have_stripped_sections;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

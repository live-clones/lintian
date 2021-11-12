# libraries/static -- lintian check script -*- perl -*-

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

package Lintian::Check::Libraries::Static;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(any none uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ m{ \b current [ ] ar [ ] archive \b }x;

    my @unstripped_members;
    my %stripped_sections_by_member;

    for my $member_name (keys %{$item->elf_by_member}) {

        my $member_elf = $item->elf_by_member->{$member_name};

        my @elf_sections = values %{$member_elf->{'SECTION-HEADERS'}};
        my @have_section_names = map { $_->name } @elf_sections;

        # These are the ones file(1) looks for.  The ".zdebug_info" being the
        # compressed version of .debug_info.
        # - Technically, file(1) also looks for .symtab, but that is apparently
        #   not strippable for static libs.  Accordingly, it is omitted below.
        my @KNOWN_DEBUG_SECTION_NAMES = qw{.debug_info .zdebug_info};
        my $lc_debug = List::Compare->new(\@have_section_names,
            \@KNOWN_DEBUG_SECTION_NAMES);

        my @have_debug_sections = $lc_debug->get_intersection;

        if (@have_debug_sections) {

            push(@unstripped_members, $member_name);
            next;
        }

        my @KNOWN_STRIPPED_SECTION_NAMES = qw{.note .comment};
        my $lc_stripped = List::Compare->new(\@have_section_names,
            \@KNOWN_STRIPPED_SECTION_NAMES);

        my @have_stripped_sections = $lc_stripped->get_intersection;

        $stripped_sections_by_member{$member_name} //= [];
        push(
            @{$stripped_sections_by_member{$member_name}},
            @have_stripped_sections
        );
    }

    $self->hint('unstripped-static-library', $item->name,
            $LEFT_PARENTHESIS
          . join($SPACE, sort +uniq @unstripped_members)
          . $RIGHT_PARENTHESIS)
      if @unstripped_members
      && $item->name !~ m{ _g [.]a $}x;

    # "libfoo_g.a" is usually a "debug" library, so ignore
    # unneeded sections in those.
    for my $member (keys %stripped_sections_by_member) {

        $self->hint(
            'static-library-has-unneeded-sections',
            $item->name,
            "($member)",
            join($SPACE, sort +uniq @{$stripped_sections_by_member{$member}}))
          if @{$stripped_sections_by_member{$member}}
          && $item->name !~ m{ _g [.]a $}x;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

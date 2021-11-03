# archive/liberty/mismatch -- lintian check script -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Check::Archive::Liberty::Mismatch;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(all none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

const my $ARROW => q{->};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;
    my $source_fields = $control->source_fields;

    # Check that every package is in the same archive area, except
    # that sources in main can deliver both main and contrib packages.
    # The source package may or may not have a section specified; if
    # it doesn't, derive the expected archive area from the first
    # binary package by leaving $source_liberty undefined until parsing the
    # first binary section.  Missing sections will be caught by other
    # checks.

    my $source_section = $source_fields->value('Section');
    return
      unless length $source_section;

    # see policy 2.4
    $source_section = "main/$source_section"
      if $source_section !~ m{/};

    my $source_liberty = $source_section;
    $source_liberty =~ s{ / .* $}{}x;

    my %liberty_by_installable;

    for my $installable ($control->installables) {

        my $installable_fields = $control->installable_fields($installable);

        my $installable_section;
        if ($installable_fields->declares('Section')) {

            $installable_section = $installable_fields->value('Section');

            # see policy 2.4
            $installable_section = "main/$installable_section"
              if $installable_section !~ m{/};
        }

        $installable_section ||= $source_section;

        my $installable_liberty = $installable_section;
        $installable_liberty =~ s{ / .* $}{}x;

        $liberty_by_installable{$installable} = $installable_liberty;

        # special exception for contrib built from main
        next
          if $source_liberty eq 'main' && $installable_liberty eq 'contrib';

        $self->hint(
            'archive-liberty-mismatch',
            "$installable_liberty vs $source_liberty",
            "(in section for $installable)",
            $LEFT_SQUARE_BRACKET
              . 'debian/control:'
              . $installable_fields->position('Section')
              . $RIGHT_SQUARE_BRACKET
        )if $source_liberty ne $installable_liberty;
    }

    # in ascending order of liberty
    for my $inferior_liberty ('non-free', 'contrib') {

        # must remain inferior
        last
          if $inferior_liberty eq $source_liberty;

        $self->hint(
            'archive-liberty-mismatch',
            $source_liberty,
            $ARROW,
            $inferior_liberty,
            '(in source paragraph)',
            $LEFT_SQUARE_BRACKET
              . 'debian/control:'
              . $source_fields->position('Section')
              . $RIGHT_SQUARE_BRACKET
          )
          if (
            all { $liberty_by_installable{$_} eq $inferior_liberty }
            keys %liberty_by_installable
          )
          && (
            none { $liberty_by_installable{$_} eq $source_liberty }
            keys %liberty_by_installable
          );
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

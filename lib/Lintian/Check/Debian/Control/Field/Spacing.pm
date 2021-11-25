# debian/control/field/spacing -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Control::Field::Spacing;

use v5.20;
use warnings;
use utf8;

use Lintian::Pointer::Item;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item eq 'debian/control';

    my @lines = split(/\n/, $item->decoded_utf8);

    my $position = 1;
    while (defined(my $line = shift @lines)) {

        # strip leading spaces
        $line =~ s{\s*$}{};

        next
          if $line =~ m{^ [#]}x;

        # line with field:
        if ($line =~ m{^ (\S+) : }x) {

            my $field = $1;

            my $pointer = Lintian::Pointer::Item->new;
            $pointer->item($item);
            $pointer->position($position);

            $self->pointed_hint('debian-control-has-unusual-field-spacing',
                $pointer, $field)
              unless $line =~ m{^ \S+ : [ ] \S }x
              || $line =~ m{^ \S+ : $}x;
        }

    } continue {
        ++$position;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

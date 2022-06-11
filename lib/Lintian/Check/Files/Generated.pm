# files/generated -- lintian check script -*- perl -*-

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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Files::Generated;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

const my $DOUBLE_QUOTE => q{"};

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    # check all patched source files except the Debian patches
    return
      if $item->name =~ m{^ debian/patches/ }x;

    return
      unless $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        if ($line
            =~m{ ( This [ ] file [ ] (?: is | was ) [ ] autogenerated ) }xi
            || $line
            =~ m{ ( DO [ ] NOT [ ] EDIT [ ] (?: THIS [ ] FILE [ ] )? BY [ ] HAND ) }xi
        ) {

            my $marker = $1;

            $self->pointed_hint(
                'generated-file',
                $item->pointer($position),
                $DOUBLE_QUOTE . $marker . $DOUBLE_QUOTE
            );
        }

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

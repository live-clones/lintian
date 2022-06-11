# debian/trailing-whitespace -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIES
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Check::Debian::TrailingWhitespace;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $KEEP_EMPTY_FIELDS => -1;
const my $LAST_ITEM => -1;

# list of files to check for a trailing whitespace characters
my %PROHIBITED_TRAILS = (
    'debian/changelog'        => qr{\s+$},
    'debian/control'          => qr{\s+$},
    # allow trailing tabs in make
    'debian/rules'            => qr{[ ]+$},
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless exists $PROHIBITED_TRAILS{$item->name};

    return
      unless $item->is_valid_utf8;

    my $contents = $item->decoded_utf8;
    my @lines = split(/\n/, $contents, $KEEP_EMPTY_FIELDS);

    my @trailing_whitespace;
    my @empty_at_end;

    my $position = 1;
    for my $line (@lines) {

        push(@trailing_whitespace, $position)
          if $line =~ $PROHIBITED_TRAILS{$item->name};

        # keeps track of any empty lines at the end
        if (length $line) {
            @empty_at_end = ();
        } else {
            push(@empty_at_end, $position);
        }

    } continue {
        ++$position;
    }

    # require a newline at end and remove it
    if (scalar @empty_at_end && $empty_at_end[$LAST_ITEM] == scalar @lines){
        pop @empty_at_end;
    } else {
        $self->pointed_hint('no-newline-at-end', $item->pointer);
    }

    push(@trailing_whitespace, @empty_at_end);

    $self->pointed_hint('trailing-whitespace', $item->pointer($_))
      for @trailing_whitespace;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

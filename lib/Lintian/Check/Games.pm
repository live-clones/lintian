# games -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Games;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    # non-games-specific data in games subdirectory
    if ($item->name=~ m{^usr/share/games/(?:applications|mime|icons|pixmaps)/}
        && !$item->is_dir) {

        $self->pointed_hint('global-data-in-games-directory', $item->pointer);
    }

    return;
}

sub dir_counts {
    my ($self, $filename) = @_;

    my $item = $self->processable->installed->lookup($filename);

    return 0
      unless $item;

    return scalar $item->children;
}

sub installable {
    my ($self) = @_;

    my $section = $self->processable->fields->value('Section');

    # section games but nothing in /usr/games
    # any binary counts to avoid game-data false positives:
    my $games = $self->dir_counts('usr/games/');
    my $other = $self->dir_counts('bin/') + $self->dir_counts('usr/bin/');

    if ($other) {
        if ($section =~ m{games$}) {

            if ($games) {
                $self->hint('package-section-games-but-has-usr-bin');

            } else {
                $self->hint('package-section-games-but-contains-no-game');
            }
        }

    } elsif ($games > 0 and $section !~ m{games$}) {
        $self->hint('game-outside-section');
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# debian/watch/standard -- lintian check script -*- perl -*-
#
# Copyright © 2020 Felix Lechner
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

package Lintian::Check::Debian::Watch::Standard;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::Util qw(max);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

const my @STANDARDS => (2, 3, 4);
const my $NEWLY_SUPERSEEDED => 3;

sub source {
    my ($self) = @_;

    my $file = $self->processable->patched->resolve_path('debian/watch');
    return
      unless $file;

    my $contents = $file->bytes;
    return
      unless length $contents;

    # look for version
    my @mentioned = ($contents =~ /^ version \s* = \s* (\d+) \s* $/gmsx);

    my $has_contents = !!($contents =~ m{^ \s* [^#] }gmx);

    if ($has_contents && !@mentioned) {

        $self->hint('missing-debian-watch-file-standard');
        return;
    }

    $self->hint('multiple-debian-watch-file-standards',
        join($SPACE, @mentioned))
      if @mentioned > 1;

    my $standard_lc = List::Compare->new(\@mentioned, \@STANDARDS);
    my @unknown = $standard_lc->get_Lonly;
    my @known = $standard_lc->get_intersection;

    $self->hint('unknown-debian-watch-file-standard', $_)for @unknown;

    return
      unless @known;

    my $highest = max(@known);
    $self->hint('debian-watch-file-standard', $highest);

    $self->hint('older-debian-watch-file-standard', $highest)
      if $highest == $NEWLY_SUPERSEEDED;

    $self->hint('obsolete-debian-watch-file-standard', $highest)
      if $highest < $NEWLY_SUPERSEEDED;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

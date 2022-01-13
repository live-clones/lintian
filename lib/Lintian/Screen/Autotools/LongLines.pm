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

package Lintian::Screen::Autotools::LongLines;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Screen';

sub suppress {
    my ($self, $processable, $hint) = @_;

    my $item = $hint->pointer->item;

    # ./configure script in source root only
    return 1
      if $item->name eq 'configure'
      && ( defined $processable->patched->resolve_path('configure.in')
        || defined $processable->patched->resolve_path('configure.ac'));

    # Automake's Makefile.in in any folder
    return 1
      if $item->basename eq 'Makefile.in'
      && defined $processable->patched->resolve_path(
        $item->dirname . '/Makefile.am');

    # any m4 macro as long as ./configure is present
    return 1
      if $item->name =~ m{^ m4/ }x
      && defined $processable->patched->resolve_path('configure');

    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

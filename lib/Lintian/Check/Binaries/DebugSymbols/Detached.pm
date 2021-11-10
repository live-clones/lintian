# binaries/debug-symbols/detached -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::DebugSymbols::Detached;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    return
      unless $item->file_info =~ m{ executable | shared [ ] object }x;

    # Detached debugging symbols directly in /usr/lib/debug.
    $self->hint('debug-symbols-directly-in-usr-lib-debug', $item)
      if $item->dirname eq 'usr/lib/debug/';

    return
      unless $item->name
      =~ m{^ usr/lib/debug/ (?:lib\d*|s?bin|usr|opt|dev|emul|\.build-id) / }x;

    $self->hint('debug-symbols-not-detached', $item)
      if exists $item->elf->{NEEDED};

    # Something other than detached debugging symbols in
    # /usr/lib/debug paths.
    my @DEBUG_SECTIONS = qw{.debug_line .zdebug_line .debug_str .zdebug_str};
    $self->hint('debug-file-with-no-debug-symbols', $item)
      if none { exists $item->elf->{SH}{$_} } @DEBUG_SECTIONS;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

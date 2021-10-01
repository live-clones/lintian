# binaries/debug-symbols -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::DebugSymbols;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Guile object files do not objdump/strip correctly, so exclude them
# from a number of tests. (#918444)
const my $GUILE_PATH_REGEX => qr{^usr/lib(?:/[^/]+)+/guile/[^/]+/.+\.go$};

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    # Is it an object file (which generally cannot be
    # stripped), a kernel module, debugging symbols, or
    # perhaps a debugging package?
    $self->hint('unstripped-binary-or-object', $item)
      if $item->file_info =~ m{ \b not [ ] stripped \b }x
      && $item->name !~ m{ [.]k?o $}x
      && $self->processable->name !~ m{ -dbg $}x
      && $item->name !~ m{^ (?:usr/)? lib/debug/ }x
      && $item->name !~ $GUILE_PATH_REGEX
      && $item->name !~ m{ [.]gox $}x
      && ( $item->file_info !~ m/executable/
        || $item->strings !~ m{^ Caml1999X0[0-9][0-9] $}mx);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

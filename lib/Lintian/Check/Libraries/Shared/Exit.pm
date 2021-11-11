# libraries/shared/exit -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Libraries::Shared::Exit;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# not presently used
#my $UNKNOWN_SHARED_LIBRARY_EXCEPTIONS
#  = $self->profile->load_data('shared-libs/unknown-shared-library-exceptions');

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # shared library
    return
      unless @{$item->elf->{SONAME} // [] };

    my @symbols = grep { $_->section eq '.text' || $_->section eq 'UND' }
      @{$item->elf->{SYMBOLS} // []};

    my @symbol_names = map { $_->name } @symbols;

    # If it has an INTERP section it might be an application with
    # a SONAME (hi openjdk-6, see #614305).  Also see the comment
    # for "shared-library-is-executable" below.
    $self->hint('exit-in-shared-library', $item->name)
      if (any { m/^_?exit$/ } @symbol_names)
      && (none { $_ eq 'fork' } @symbol_names)
      && !length $item->elf->{INTERP};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

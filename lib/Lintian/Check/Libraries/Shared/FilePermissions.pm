# libraries/shared/file-permissions -- lintian check script -*- perl -*-

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

package Lintian::Check::Libraries::Shared::FilePermissions;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $WIDELY_READABLE => oct(644);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # shared library
    return
      unless @{$item->elf->{SONAME} // [] };

    # Yes.  But if the library has an INTERP section, it's
    # designed to do something useful when executed, so don't
    # report an error.  Also give ld.so a pass, since it's
    # special.
    $self->hint('shared-library-is-executable',
        $item->name, $item->octal_permissions)
      if $item->is_executable
      && !$item->elf->{INTERP}
      && $item->name !~ m{^lib.*/ld-[\d.]+\.so$};

    $self->hint('odd-permissions-on-shared-library',
        $item->name, $item->octal_permissions)
      if !$item->is_executable
      && $item->operm != $WIDELY_READABLE;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

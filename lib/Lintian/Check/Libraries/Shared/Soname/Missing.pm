# libraries/shared/soname/missing -- lintian check script -*- perl -*-

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

package Lintian::Check::Libraries::Shared::Soname::Missing;

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
      unless $item->file_info =~ m{^ [^,]* \b ELF \b }x;

    return
      unless $item->file_info
      =~ m{(?: shared [ ] object | pie [ ] executable )}x;

    # does not have SONAME
    return
      if @{$item->elf->{SONAME} // [] };

    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};
    return
      if none { $item->dirname eq $_ } @ldconfig_folders;

    # disregard executables
    $self->hint('sharedobject-in-library-directory-missing-soname',$item->name)
      if !$item->is_executable
      || !defined $item->elf->{DEBUG}
      || $item->name =~ / [.]so (?: [.] | $ ) /msx;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

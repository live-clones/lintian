# libraries/shared/stack -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
# Copyright (C) 2018-2019 Chris Lamb <lamby@debian.org>
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Libraries::Shared::Stack;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # shared library
    return
      unless @{$item->elf->{SONAME} // [] };

    $self->pointed_hint('shared-library-lacks-stack-section',$item->pointer)
      if $self->processable->fields->declares('Architecture')
      && !exists $item->elf->{PH}{STACK};

    $self->pointed_hint('executable-stack-in-shared-library', $item->pointer)
      if exists $item->elf->{PH}{STACK}
      && $item->elf->{PH}{STACK}{flags} ne 'rw-'
     # Once the following line is removed again, please also remove
     # the Test-Architectures line in
     # t/recipes/checks/libraries/shared/stack/shared-libs-exec-stack/eval/desc
     # and the MIPS-related notes in
     # tags/e/executable-stack-in-shared-library.tag. See
     # https://bugs.debian.org/1025436 and
     # https://bugs.debian.org/1022787 for details
      && $self->processable->fields->value('Architecture') !~ /mips/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# libraries/shared/stack -- lintian check script -*- perl -*-

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

package Lintian::Check::Libraries::Shared::Stack;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # shared library
    my $objdump = $self->processable->objdump_info->{$item->name}{$EMPTY};
    return
      unless @{$objdump->{SONAME} // [] };

    $self->hint('shared-library-lacks-stack-section',$item->name)
      if $self->processable->fields->declares('Architecture')
      && !exists $objdump->{PH}{STACK};

    $self->hint('executable-stack-in-shared-library', $item->name)
      if exists $objdump->{PH}{STACK}
      && $objdump->{PH}{STACK}{flags} ne 'rw-';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

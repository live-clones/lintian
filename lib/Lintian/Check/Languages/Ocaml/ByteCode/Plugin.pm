# languages/ocaml/byte-code/plugin -- lintian check script -*- perl -*-
#
# Copyright © 2009 Stéphane Glondu
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

package Lintian::Check::Languages::Ocaml::ByteCode::Plugin;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    my $no_extension = $item->basename;
    $no_extension =~ s{ [.] [^.]+ $}{}x;

    # For each .cmxs file, there must be a matching .cma or .cmo file
    # (at least, in library packages)
    $self->hint('ocaml-dangling-cmxs', $item->name)
      if $item->name =~ m{ [.]cmxs $}x
      && !$item->parent_dir->child($no_extension . '.cma')
      && !$item->parent_dir->child($no_extension . '.cmo')
      && $self->processable->name =~ /^lib/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

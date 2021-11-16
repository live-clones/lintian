# languages/ocaml/byte-code/interface -- lintian check script -*- perl -*-
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

package Lintian::Check::Languages::Ocaml::ByteCode::Interface;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LAST_ITEM => -1;

sub visit_installed_files {
    my ($self, $item) = @_;

    my $no_extension = $item->basename;
    $no_extension =~ s{ [.] [^.]+ $}{}x;

    # for dune
    my $interface_name = (split(/__/, $no_extension))[$LAST_ITEM];

    # $somename.cmi should be shipped with $somename.mli or $somename.ml
    $self->hint('ocaml-dangling-cmi', $item->name)
      if $item->name =~ m{ [.]cmi $}x
      && !$item->parent_dir->child($interface_name . '.mli')
      && !$item->parent_dir->child(lc($interface_name) . '.mli')
      && !$item->parent_dir->child($interface_name . '.ml')
      && !$item->parent_dir->child(lc($interface_name) . '.ml');

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

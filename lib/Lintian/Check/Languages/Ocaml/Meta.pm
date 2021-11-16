# languages/ocaml/meta -- lintian check script -*- perl -*-
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

package Lintian::Check::Languages::Ocaml::Meta;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has has_meta => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{^ usr/lib/ocaml/ }x;

    # does the package provide a META file?
    $self->has_meta(1)
      if $item->name =~ m{ / META (?: [.] | $ ) }x;

    return;
}

sub installable {
    my ($self) = @_;

    my $prerequisites = $self->processable->relation('all');

    # If there is a META file, ocaml-findlib should at least be suggested.
    $self->hint('ocaml-meta-without-suggesting-findlib')
      if $self->has_meta
      && !$prerequisites->satisfies('ocaml-findlib');

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

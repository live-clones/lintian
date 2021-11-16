# languages/ocaml/byte-code/compiled -- lintian check script -*- perl -*-
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

package Lintian::Check::Languages::Ocaml::ByteCode::Compiled;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has provided_o => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %provided_o;

        for my $item (@{$self->processable->installed->sorted_list}) {

            for my $count (keys %{$item->ar_info}) {

                my $member = $item->ar_info->{$count}{name};
                next
                  unless length $member;

                # dirname ends in a slash
                my $virtual_path = $item->dirname . $member;

                # Note: a .o may be legitimately in several different .a
                $provided_o{$virtual_path} = $item->name;
            }
        }

        return \%provided_o;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    my $no_extension = $item->basename;
    $no_extension =~ s{ [.] [^.]+ $}{}x;

    # The .cmx counterpart: for each .cmx file, there must be a
    # matching .o file, which can be there by itself, or embedded in a
    # .a file in the same directory
    # dirname ends with a slash
    $self->hint('ocaml-dangling-cmx', $item->name)
      if $item->name =~ m{ [.]cmx $}x
      && !$item->parent_dir->child($no_extension . '.o')
      && !exists $self->provided_o->{$item->dirname . $no_extension . '.o'};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

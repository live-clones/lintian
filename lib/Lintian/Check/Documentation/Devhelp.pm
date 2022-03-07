# documentation/devhelp -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2022 Felix Lechner
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

package Lintian::Check::Documentation::Devhelp;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# *.devhelp and *.devhelp2 files must be accessible from a directory in
# the devhelp search path: /usr/share/devhelp/books and
# /usr/share/gtk-doc/html.  We therefore look for any links in one of
# those directories to another directory.  The presence of such a link
# blesses any file below that other directory.
has reachable_folders => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @reachable_folders;

        for my $item (@{$self->processable->installed->sorted_list}) {

            # in search path
            next
              unless $item->name
              =~ m{^ usr/share/ (?: devhelp/books | gtk-doc/html ) / }x;

            next
              unless length $item->link;

            my $followed = $item->link_normalized;

            # drop broken links
            push(@reachable_folders, $followed)
              if length $followed;
        }

        return \@reachable_folders;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    # locate Devhelp files not discoverable by Devhelp
    $self->pointed_hint('stray-devhelp-documentation', $item->pointer)
      if $item->name =~ m{ [.]devhelp2? (?: [.]gz )? $}x
      && $item->name !~ m{^ usr/share/ (?: devhelp/books | gtk-doc/html ) / }x
      && (none { $item->name =~ /^\Q$_\E/ } @{$self->reachable_folders});

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

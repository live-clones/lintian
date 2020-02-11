# files/symbolic-links/broken -- lintian check script -*- perl -*-
#
# Copyright (C) 2011 Niels Thykier
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

package Lintian::files::symbolic_links::broken;

use strict;
use warnings;
use autodie;

use File::Basename qw(dirname);
use List::MoreUtils qw(any);

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

has wildcard_links => (is => 'rwp', default => sub{ [] });

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_symlink;

    # target relative to the package root
    my $path = $file->link_normalized;

    # unresolvable link
    unless (defined $path) {

        $self->tag('package-contains-unsafe-symlink', $file->name);
        return;
    }

    # will always have links to the package root (although
    # self-recursive and possibly not very useful)
    return
      if $path eq EMPTY;

    # If it contains a "*" it probably a bad
    # ln -s target/*.so link expansion.  We do not bother looking
    # for other broken symlinks as people keep adding new special
    # cases and it is not worth it.
    push(@{$self->wildcard_links}, $file)
      if $file->link && index($file->link, '*') >= 0;

    return;
}

sub breakdown {
    my ($self) = @_;

    return
      unless @{$self->wildcard_links};

    # get prerequisites from same source package
    my @prerequisites
      = @{$self->group->direct_dependencies($self->processable)};

    foreach my $file (@{$self->wildcard_links}){

        # target relative to the package root
        my $path = $file->link_normalized;

        # destination is in the package
        next
          if $self->processable->index($path)
          || $self->processable->index("$path/");

        # does the link point to any prerequisites in same source package
        next
          if any { $_->index($path) || $_->index("$path/") } @prerequisites;

        # link target
        my $target = $file->link // EMPTY;

        # strip leading slashes for reporting
        $target =~ s,^/++,,o;

        # nope - not found in any of our direct dependencies.  Ergo it is
        # a broken "ln -s target/*.so link" expansion.
        $self->tag('package-contains-broken-symlink-wildcard', $file, $target);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

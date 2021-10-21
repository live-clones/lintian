# files/symbolic-links/broken -- lintian check script -*- perl -*-
#
# Copyright © 2011 Niels Thykier
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

package Lintian::Check::Files::SymbolicLinks::Broken;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename qw(dirname);
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $ASTERISK => q{*};

has wildcard_links => (is => 'rw', default => sub{ [] });

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_symlink;

    # target relative to the package root
    my $path = $file->link_normalized;

    # unresolvable link
    unless (defined $path) {

        $self->hint('package-contains-unsafe-symlink', $file->name);
        return;
    }

    # will always have links to the package root (although
    # self-recursive and possibly not very useful)
    return
      if $path eq $EMPTY;

    # If it contains a "*" it probably a bad
    # ln -s target/*.so link expansion.  We do not bother looking
    # for other broken symlinks as people keep adding new special
    # cases and it is not worth it.
    push(@{$self->wildcard_links}, $file)
      if index($file->link, $ASTERISK) >= 0;

    return;
}

sub installable {
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
          if $self->processable->installed->lookup($path)
          || $self->processable->installed->lookup("$path/");

        # does the link point to any prerequisites in same source package
        next
          if any {
            $_->installed->lookup($path) || $_->installed->lookup("$path/")
        }
        @prerequisites;

        # link target
        my $target = $file->link;

        # strip leading slashes for reporting
        $target =~ s{^/+}{};

        # nope - not found in any of our direct dependencies.  Ergo it is
        # a broken "ln -s target/*.so link" expansion.
        $self->hint('package-contains-broken-symlink-wildcard', $file,$target);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

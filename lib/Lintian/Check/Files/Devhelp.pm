# files/devhelp -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Files::Devhelp;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has related => (is => 'rw', default => sub { [] });
has links => (is => 'rw', default => sub { [] });

sub visit_installed_files {
    my ($self, $file) = @_;

    # *.devhelp and *.devhelp2 files must be accessible from a directory in
    # the devhelp search path: /usr/share/devhelp/books and
    # /usr/share/gtk-doc/html.  We therefore look for any links in one of
    # those directories to another directory.  The presence of such a link
    # blesses any file below that other directory.
    if (length $file->link
        && $file->name =~ m{^usr/share/(?:devhelp/books|gtk-doc/html)/}) {
        my $blessed = $file->link_normalized // '<broken-link>';
        push(@{$self->links}, $blessed);
    }

    # .devhelp2? files
    if (
        $file->name =~ /\.devhelp2?(?:\.gz)?$/
        # If the file is located in a directory not searched by devhelp, we
        # check later to see if it's in a symlinked directory.
        && $file->name !~ m{^usr/share/(?:devhelp/books|gtk-doc/html)/}
        && $file->name !~ m{^usr/share/doc/[^/]+/examples/}
    ) {
        push(@{$self->related}, $file->name);
    }

    return;
}

sub installable {
    my ($self) = @_;

    # Check for .devhelp2? files that aren't symlinked into paths searched by
    # devhelp.
    for my $path (@{$self->related}) {

        $self->hint('package-contains-devhelp-file-without-symlink', $path)
          if none { $path =~ /^\Q$_\E/ } @{$self->links};
    }

    $self->related([]);
    $self->links([]);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

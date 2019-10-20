# files/hard-links -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::hard_links;

use strict;
use warnings;
use autodie;

use Moo;

with('Lintian::Check');

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_hardlink;

    my $target_dir = $file->link;
    $target_dir =~ s,[^/]*$,,;

    # It may look weird to sort the file and link target here,
    # but since it's a hard link, both files are equal and
    # either could be legitimately reported first.  tar will
    # generate different tar files depending on the hashing of
    # the directory, and this sort produces stable lintian
    # output despite that.
    #
    # TODO: actually, policy says 'conffile', not '/etc' ->
    # extend!
    $self->tag('package-contains-hardlink',
        join(' -> ', sort($file->name, $file->link)))
      if $file->name =~ m,^etc/,
      or $file->link =~ m,^etc/,
      or $file->name !~ m,^\Q$target_dir\E[^/]*$,;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# files/empty-directories -- lintian check script -*- perl -*-

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

package Lintian::files::empty_directories;

use strict;
use warnings;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_dir;

    # skip base-files, which is a very special case.
    return
      if $self->package eq 'base-files';

    # ignore /var, which may hold dynamic data packages create, and /etc,
    # which may hold configuration files generated by maintainer scripts
    return
      if $file->name =~ m{^var/} || $file->name =~ m{^etc/};

    # Empty Perl directories are an ExtUtils::MakeMaker artifact that
    # will be fixed in Perl 5.10, and people can cause more problems
    # by trying to fix it, so just ignore them.
    return
      if $file->name =~ m,^usr/lib/(?:[^/]+/)?perl5/$,
      || $file->name eq 'usr/share/perl5/';

    # warn about empty directories
    $self->tag('package-contains-empty-directory', $file->name)
      if scalar $file->children == 0;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

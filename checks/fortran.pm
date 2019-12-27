# fortran -- lintian check script -*- perl -*-

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

package Lintian::fortran;

use strict;
use warnings;

use Lintian::Util qw(open_gz);

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub files {
    my ($self, $file) = @_;

    # perhaps an unnecessary precaution
    return
      unless $file->name =~ m{^usr/lib/};

    # file-info would be great, but files are zipped
    return
      unless $file->name =~ m{\.mod$};

    # allow for subdirectories in between
    return
      unless $file->name =~ m{/fortran/};

    return
      unless $file->is_file && $file->is_open_ok;

    my $module_version;

    my $fd = open_gz($file->fs_path);
    while (<$fd>) {
        next
          if /^\s*$/;

        ($module_version) = ($_ =~ /^GFORTRAN module version '(\d+)'/);
        last;
    }

    close($fd);

    unless (length $module_version) {
        $self->tag('fortran-module-does-not-declare-version', $file->name);
        return;
    }

    my $depends = $self->processable->field('depends') // EMPTY;
    $self->tag('missing-prerequisite-for-fortran-module', $file->name)
      unless $depends =~ /\bgfortran-mod-$module_version\b/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

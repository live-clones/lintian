# files -- lintian check script -*- perl -*-

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

package Lintian::files;

use strict;
use warnings;
use autodie;

use Moo;

use File::Find::Rule;
use Path::Tiny;

with('Lintian::Check');

sub always {
    my ($self) = @_;

    # temporary setup until split is finalized
    # tags and tests will be divided and reassigned later

    # call submodules for now
    my @submodules = sort File::Find::Rule->file->name('*.pm')
      ->in("$ENV{LINTIAN_ROOT}/checks/files");

    for my $submodule (@submodules) {

        my $name = path($submodule)->basename('.pm');
        my $dir = path($submodule)->parent->stringify;

        # skip checks that already stand on their own
        next
          if -e "$dir/$name.desc";

        require $submodule;

        # replace hyphens with underscores
        $name =~ s/-/_/g;

        my $subpackage = "Lintian::files::$name";
        my $check = $subpackage->new;
        $check->processable($self->processable);
        $check->group($self->group);

        $check->run;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

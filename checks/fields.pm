# fields -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::fields;

use strict;
use warnings;
use autodie;

use File::Find::Rule;
use Path::Tiny;

sub always {
    my ($pkg, $type, $info, $proc, $group) = @_;

    # temporary setup until split is finalized
    # tags and tests will be divided and reassigned later

    # call submodules for now
    my @submodules = sort File::Find::Rule->file->name('*.pm')
      ->in("$ENV{LINTIAN_ROOT}/checks/fields");

    for my $submodule (@submodules) {

        my $name = path($submodule)->basename('.pm');
        my $dir = path($submodule)->parent->stringify;

        # skip checks that already stand on their own
        next
          if -e "$dir/$name.desc";

        require $submodule;

        # replace hyphens with underscores
        $name =~ s/-/_/g;

        my $check = "Lintian::fields::$name";
        my @args = ($pkg, $type, $info, $proc, $group);

        $check->can($type)->(@args)
          if $check->can($type);

        $check->can('always')->(@args)
          if $check->can('always');
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

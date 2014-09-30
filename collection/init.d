#!/usr/bin/perl -w
# init.d -- lintian collector script

# Copyright (C) 1998 Richard Braakman
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

package Lintian::coll::init_d;

use strict;
use warnings;
use autodie;

use lib "$ENV{'LINTIAN_ROOT'}/lib";
use Lintian::Util qw(copy_dir delete_dir fail is_ancestor_of);

sub collect {
    my (undef, $type, $dir) = @_;

    if (-e "$dir/init.d") {
        delete_dir("$dir/init.d")
          or fail('cannot rm old init.d directory');
    }

    # If we are asked to only remove the files stop right here
    if ($type =~ m/^remove-/) {
        return;
    }

    if (-d "$dir/unpacked/etc/init.d") {
        if (!is_ancestor_of("$dir/unpacked", "$dir/unpacked/etc/init.d")) {
            # Unsafe, stop
            return;
        }

        copy_dir("$dir/unpacked/etc/init.d", "$dir/init.d")
          or fail('cannot copy init.d directory');
    }

    return;
}

collect(@ARGV) if $0 =~ m,(?:^|/)init\.d$,;

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

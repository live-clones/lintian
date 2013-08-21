#!/usr/bin/perl

# Copyright (C) 2009 by Raphael Geissert <atomo64@gmail.com>
# Copyright (C) 2009 Russ Allbery <rra@debian.org>
#
# This file is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use Test::More;

use Lintian::CollScript;
use Lintian::Util qw(read_dpkg_control);

$ENV{'LINTIAN_ROOT'} //= '.';
$ENV{'LINTIAN_HELPER_DIRS'} = "$ENV{'LINTIAN_ROOT'}/helpers";

# Find all of the desc files in collection.  We'll do one check per
# description.  We don't check checks/*.desc because check-desc.t
# handles that.
our @DESCS = (glob("$ENV{LINTIAN_ROOT}/collection/*.desc"));
plan tests => scalar(@DESCS);

# For each desc file, load the first stanza of the file and check that all of
# its Needs-Info script references exist.
for my $desc (@DESCS) {
    my $coll = Lintian::CollScript->new($desc);
    my $name = $coll->name;
    my @needs = $coll->needs_info;
    my @missing;

    for my $coll (@needs) {
        unless (-f "$ENV{LINTIAN_ROOT}/collection/$coll") {
            push @missing, $coll;
        }
    }
    is(join(', ', @missing), '', "$name has valid needs-info");
}

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

use Test::More;
use Lintian::CollScript;
use Lintian::Util qw(read_dpkg_control);

# Find all of the desc files in either collection or checks.  We'll do one
# check per description.
our @DESCS = (<$ENV{LINTIAN_ROOT}/collection/*.desc>,
              <$ENV{LINTIAN_ROOT}/checks/*.desc>);
plan tests => scalar(@DESCS);

# For each desc file, load the first stanza of the file and check that all of
# its Needs-Info script references exist.
for my $desc (@DESCS) {
    my ($header) = read_dpkg_control($desc);
    my @needs;
    my @missing;

    if ($header->{'collector-script'}) {
        my $coll = Lintian::CollScript->new ($desc);
        @needs = $coll->needs_info;
    } else {
        @needs = split(/\s*,\s*/, $header->{'needs-info'} || '');
    }
    for my $coll (@needs) {
        unless (-f "$ENV{LINTIAN_ROOT}/collection/$coll") {
            push(@missing, $coll);
        }
    }
    my $short = $desc;
    $short =~ s/^\Q$ENV{LINTIAN_ROOT}//;
    is(join(', ', @missing), '', "$short has valid needs-info");
}

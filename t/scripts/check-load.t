#!/usr/bin/perl

# Copyright (C) 2012 Niels Thykier
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

use strict;
use warnings;

use Const::Fast;
use Test::More import => ['done_testing'];

use Test::Lintian;

const my $DOT => q{.};

# Test that all checks can be loaded (except lintian.desc, which is
# a special case).
sub accept_filter {
    return !m{/lintian\.desc$};
}

my $opts = {'filter' => \&accept_filter,};

$ENV{'LINTIAN_BASE'} //= $DOT;

load_profile_for_test('debian/main', $ENV{'LINTIAN_BASE'});
test_load_checks($opts, "$ENV{'LINTIAN_BASE'}/lib/Lintian/Check");

done_testing;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

# Copyright (C) 2022 Axel Beckert
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

# The harness for Lintian's test suite.  For detailed information on
# the test suite layout and naming conventions, see t/tests/README.
# For more information about running tests, see
# doc/tutorial/Lintian/Tutorial/TestSuite.pod
#

use strict;
use warnings;
use v5.10;

use Test::More;
use Lintian::Util qw(match_glob);

is_deeply([match_glob('foo*bar', qw(foo bar foobar foobazbar xfoobazbary))],
    [qw(foobar foobazbar)],'match_glob() with simple * wildcard');

is_deeply([match_glob('fo?bar', qw(foo bar foobar foobazbar xfoobarbaz))],
    [qw(foobar)],'match_glob() with simple ? wildcard');

is_deeply(
    [match_glob('foo*[baz]', qw(foo foo[baz] foobar[baz]))],
    [qw(foo[baz] foobar[baz])],
    'match_glob() with * wildcard and literal brackets'
);

is_deeply(
    [match_glob('foo*{baz}', qw(foo foo{baz} foobar{baz} xfoobar{baz}y))],
    [qw(foo{baz} foobar{baz})],
    'match_glob() with * wildcard and literal curly braces'
);

is_deeply(
    [match_glob('foo*(baz)', qw[foo foo(baz) foobar(baz) xfoobar(baz)y])],
    [qw[foo(baz) foobar(baz)]],
    'match_glob() with * wildcard and literal parentheses'
);

is_deeply([match_glob('foo.bar', qw(foo.bar foo|bar foo&bar xfoo.bary))],
    [qw(foo.bar)],'match_glob() with no wildcard but a literal dot');

done_testing();

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

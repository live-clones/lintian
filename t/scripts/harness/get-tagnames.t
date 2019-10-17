#!/usr/bin/perl

# Copyright © 2019 Felix Lechner
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
# MA 02110-1301, USA

use strict;
use warnings;
use autodie;

BEGIN {
    die('Cannot find LINTIAN_TEST_ROOT')
      unless length $ENV{'LINTIAN_TEST_ROOT'};
}

use List::MoreUtils qw(uniq);
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_TEST_ROOT'}/lib";
use Test::Lintian::Output::Universal qw(get_tagnames);

# dummy tags
my $tagstext =<<EOSTR;
distribution-multiple-bad (changes): bad-distribution-in-changes-file foo-backportss
distribution-multiple-bad (changes): bad-distribution-in-changes-file foo
distribution-multiple-bad (changes): bad-distribution-in-changes-file bar
distribution-multiple-bad (changes): backports-upload-has-incorrect-version-number 1.0
distribution-multiple-bad (changes): backports-changes-missing
EOSTR
my $tagspath = Path::Tiny->tempfile;
$tagspath->spew($tagstext);

# read tag names from file
my @actual = sort +uniq +get_tagnames($tagspath->stringify);

my @expected = (
    'backports-changes-missing',
    'backports-upload-has-incorrect-version-number',
    'bad-distribution-in-changes-file'
);

# test plan
plan tests => 1;

# check when tags match
is_deeply(\@actual, \@expected, 'Tags read via get_tagnames match');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

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

BEGIN {
    die('Cannot find LINTIAN_BASE')
      unless length $ENV{'LINTIAN_BASE'};
}

use List::SomeUtils qw(uniq);
use Path::Tiny;
use Test::More;

use lib "$ENV{'LINTIAN_BASE'}/lib";
use Test::Lintian::Output::Universal qw(get_tagnames);

# dummy hints
my $hintstext =<<'EOSTR';
distribution-multiple-bad (changes): bad-distribution-in-changes-file foo-backportss
distribution-multiple-bad (changes): bad-distribution-in-changes-file foo
distribution-multiple-bad (changes): bad-distribution-in-changes-file bar
distribution-multiple-bad (changes): backports-upload-has-incorrect-version-number 1.0
distribution-multiple-bad (changes): backports-changes-missing
EOSTR
my $hintspath = Path::Tiny->tempfile;
$hintspath->spew($hintstext);

# read tag names from file
my @actual = sort +uniq +get_tagnames($hintspath->stringify);

my @expected = qw(
  backports-changes-missing
  backports-upload-has-incorrect-version-number
  bad-distribution-in-changes-file
);

# test plan
plan tests => 1;

# check when hints match
is_deeply(\@actual, \@expected, 'Tags read via get_tagnames match');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

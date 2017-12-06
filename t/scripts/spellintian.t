#!/usr/bin/perl

# Copyright © 2014-2016 Jakub Wilk <jwilk@jwilk.net>
# Copyright © 2017 Axel Beckert <abe@debian.org>
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
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

use Test::More tests => 7;

use IPC::Run();

$ENV{'LINTIAN_TEST_ROOT'} //= '.';

my $cmd_path = "$ENV{LINTIAN_TEST_ROOT}/frontend/spellintian";
my $spelling_data = 'data/spelling/corrections';

sub t {
    my ($input, $expected, @options) = @_;
    my $output;
    my $cmd
      = IPC::Run::start([$cmd_path, @options],'<', \$input,'>', \$output,);
    $cmd->finish;
    cmp_ok($cmd->result, '==', 0, 'exit code 0');
    cmp_ok($output, 'eq', $expected, 'expected output');
    return;
}

my $s = "A familar brown gnu allows\nto jump over the lazy dog.\n";

t($s, "familar -> familiar\nallows to -> allows one to\n");
t($s, "familar -> familiar\nallows to -> allows one to\ngnu -> GNU\n",
    '--picky');

my $iff = 0;
my $publically = 0;
my $case_sen = 0;

open(my $sp_fh, '<', $spelling_data)
  or die "Can't open $spelling_data for reading: $!";
while (my $corr = <$sp_fh>) {
    next if $corr =~ m{ ^\# | ^$ }x;
    chomp($corr);

    # Check if case sensitive corrections have been added to the wrong
    # file (data/spelling/corrections, not data/spelling/corrections-case).
    # Bad example from #883041: german||German
    my ($wrong, $good) = split(/\|\|/, $corr);
    $case_sen++ if ($wrong eq lc($good));

    # Check if "iff" has been added as correction. See #865055 why
    # this is wrong. Bad example: iff||if
    $iff++ if $corr =~ m{ ^ iff \|\| }x;

    # Check if "publically" has been added as correction. It is a
    # seldom, but valid English word, is used in the OpenSSL license
    # and hence causes quite some false positives, when being added
    # (again).
    $publically++ if $corr =~ m{ ^ publically \|\| }x;
}
close($sp_fh);

ok($case_sen == 0, "No case sensitive correction present in ${spelling_data}");
ok(
    $iff == 0,
    '"iff" is not present in '
      . $spelling_data
      .'. See #865055 why this is wrong.'
);
ok(
    $publically == 0,
    '"publically" is not present in '
      . $spelling_data
      .q{. It's a valid English word and used in the OpenSSL license.}
);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

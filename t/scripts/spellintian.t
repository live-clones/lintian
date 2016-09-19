#!/usr/bin/perl

# Copyright © 2014-2016 Jakub Wilk <jwilk@jwilk.net>
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

use Test::More tests => 4;

use IPC::Run();

$ENV{'LINTIAN_TEST_ROOT'} //= '.';

my $cmd_path = "$ENV{LINTIAN_TEST_ROOT}/frontend/spellintian";

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

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

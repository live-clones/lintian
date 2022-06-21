#!/usr/bin/perl

# Copyright (C) 2014-2016 Jakub Wilk <jwilk@jwilk.net>
# Copyright (C) 2017-2022 Axel Beckert <abe@debian.org>
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

use Const::Fast;
use IPC::Run3;
use Test::More;

const my $NEWLINE => qq{\n};
const my $DOT => q{.};
const my $WAIT_STATUS_SHIFT => 8;

$ENV{'LINTIAN_BASE'} //= $DOT;
my $cmd_dir = "$ENV{LINTIAN_BASE}/private";

sub t {
    my ($cmd, $expected, $expected_stderr) = @_;
    $expected_stderr //= qr/\A\Z/;
    my $input = undef;

    my @command = ("$cmd_dir/$cmd");
    my $output;
    my $error;
    run3(\@command, \$input, \$output, \$error);

    my $status = ($? >> $WAIT_STATUS_SHIFT);
    is($status, 0, "Exit status 0 of $cmd");
    like($error, $expected_stderr, 'STDERR of $cmd matches $expected_stderr');
    like($output, $expected, "Expected output of $cmd");

    return;
}

t('auto-reject-diff', qr/Found \d+ certain/);
t('generate-tag-summary', qr/Assuming commit range to be/, qr/tags/);
t('latest-policy-version', qr/^(\d+\.){3}/);

done_testing();

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

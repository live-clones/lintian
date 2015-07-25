#!/usr/bin/perl

# Copyright © 2014 Jakub Wilk <jwilk@jwilk.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
    $cmd->finish();
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

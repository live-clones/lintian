#!/usr/bin/perl

# Copyright (C) 2026 Nicholas Guriev <nicholas@guriev.su>
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

use strict;
use warnings;
use utf8;

use autodie;

use Const::Fast;
use Encode;
use Fcntl qw/ F_SETFD /;
use File::Temp qw/ tempdir tempfile /;
use IPC::Run3;
use Path::Tiny;
use Test::More tests => 9;

const my $AMP => q{&};
const my $DOT => q{.};
const my $EMPTY => q{};
const my $IDEOGRAPHIC_SPACE => "\x{3000}";
const my $MINUS => q{-};
const my $NBSP => qq{\xA0};
const my $NUMBERIC_NE => q{!=};
const my $SPACE => q{ };
const my $TAB => qq{\t};

const my $ASCII_GREETINGS => 'hello bonjour';
const my $GREETINGS => "${ASCII_GREETINGS} привет 今日は";
const my $TEMPFILE_TEMPLATE => 'X' x 10;
const my $WAIT_STATUS_SHIFT => 8;

$ENV{'LINTIAN_BASE'} //= $DOT;
my $testee = "$ENV{LINTIAN_BASE}/bin/lintian";

sub run_single {
    my ($options, $expected) = @_;

    plan(tests => 3);
    my @command = ($testee, @{ $options });
    my ($input, $output, $error);

    note("@command");
    run3(\@command, \$input, \$output, \$error);
    note($error);

    my $status = ($? >> $WAIT_STATUS_SHIFT);
    cmp_ok($status, $NUMBERIC_NE, 0, 'errorful exit status');
    is($output, $EMPTY, 'empty output');

    my $regex = quotemeta($expected) =~ s/X/./gr;
    like(decode('UTF-8', $error), qr/^${regex}$/);

    return;
}

sub run_multiline {
    my %params = @_;

    my ($options, $input, $expected) = @params{qw/ options input expected /};
    $input //= \undef;  # if no input specified, redirect from /dev/null

    plan(tests => 2 + @{ $expected });
    run3([$testee, @{ $options }], $input, \my $output, \my $error);

    my $status = ($? >> $WAIT_STATUS_SHIFT);
    cmp_ok($status, $NUMBERIC_NE, 0, 'errorful exit status');
    is($output, $EMPTY, 'empty output');

    $error = decode('UTF-8', $error);
    like($error, $_, 'errors match') for @{ $expected };

    return;
}

my (undef, $tmp_utf8_filename) = tempfile(
    $TEMPFILE_TEMPLATE,
    SUFFIX => encode('UTF-8', " ${GREETINGS} README.txt"),
    UNLINK => 1,
);
my (undef, $tmp_eucjp_filename) = tempfile(
    $TEMPFILE_TEMPLATE,
    SUFFIX => encode('EUC-JP', " ${GREETINGS} README.md"),
    UNLINK => 1,
);

subtest $EMPTY, \&run_single,
  [encode('UTF-8', "/nonexistent/${GREETINGS}/test_1.0-1.dsc")],
  "/nonexistent/${GREETINGS}/test_1.0-1.dsc is not a readable file\n";
subtest $EMPTY, \&run_single,
  [encode('EUC-JP', "/nonexistent/${GREETINGS}/test_1.0-1.dsc")],
  "/nonexistent/${ASCII_GREETINGS} {hex:A7.E1.A7.E2.A7.DA.A7.D3.A7.D6.A7.E4} "
  . "{hex:BA.A3.C6.FC.A4.CF}/test_1.0-1.dsc is not a readable file\n";
subtest $EMPTY, \&run_single, [$tmp_utf8_filename],
  "bad package file name ${TEMPFILE_TEMPLATE} ${GREETINGS} README.txt "
  . "(neither .deb, .udeb, .ddeb, .changes, .dsc or .buildinfo file)\n";
subtest $EMPTY, \&run_single, [$tmp_eucjp_filename],
  "bad package file name ${TEMPFILE_TEMPLATE} ${ASCII_GREETINGS} "
  . '{hex:A7.E1.A7.E2.A7.DA.A7.D3.A7.D6.A7.E4} {hex:BA.A3.C6.FC.A4.CF} README.md '
  . "(neither .deb, .udeb, .ddeb, .changes, .dsc or .buildinfo file)\n";

my $stagedir = tempdir(CLEANUP => 1);
path(my $empty_source = "${stagedir}/hello_1.0-1.dsc")->touch;
path(my $empty_changes = "${stagedir}/hello_1.0-1_amd64.changes")->touch;

my ($fh, $pkglist_filename) = tempfile(UNLINK => 1);
$fh->say(encode 'UTF-8', $empty_source);
# The next line contains only spaces and is expected to be ignored.
$fh->say(encode 'UTF-8', $SPACE . $TAB . $NBSP . $IDEOGRAPHIC_SPACE);
$fh->say(encode 'UTF-8', $empty_changes);
seek $fh, 0, 'SEEK_SET';  # rewind to start
fcntl $fh, F_SETFD, 0;  # reset close-on-exec

my $expected_regex_list = [
qr/^Skipping \Q${empty_source}\E: \Q${empty_source}\E is not valid dsc file at .../m,
qr/^Skipping \Q${empty_changes}\E: \Q${empty_changes}\E is not a valid changes file at .../m,
    qr/^No packages selected\.$/m,
    qr/\bSkipping\b.+\bSkipping\b/s,  # at least two attempts were made
];

subtest 'read package list from stdin', \&run_multiline,
  (
    options => ['--packages-from-file', $MINUS],
    input => $pkglist_filename,
    expected => $expected_regex_list,
  );
subtest 'read package list from named file', \&run_multiline,
  (
    options => ['--packages-from-file', $pkglist_filename],
    expected => $expected_regex_list,
  );
subtest 'read package list from file descriptor', \&run_multiline,
  (
    options => ['--packages-from-file', $AMP . fileno($fh)],
    expected => $expected_regex_list,
  );

subtest 'non-existent package list raises an error', \&run_single,
  ['--packages-from-file', '/nonexistent/pkglist.txt'],
  "open /nonexistent/pkglist.txt for reading: No such file or directory\n";
subtest 'package list comes only from one source', \&run_multiline,
  options => ['--packages-from-file', $pkglist_filename, $empty_changes],
  expected => [
    qr{
      ^\Qoption --packages-from-file cannot be mixed with package parameters!\E\n
      \Q(will ignore --packages-from-file option)\E\n...
    }x
  ];

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 2
# End:
# vim: syntax=perl sw=2 sts=2 sr et

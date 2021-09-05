# Copyright © 2018 Felix Lechner
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

package Test::Lintian::Hooks;

=head1 NAME

Test::Lintian::Hooks -- hook routines for the test runners

=head1 SYNOPSIS

  use Test::Lintian::Hooks qw(sed_hook);
  sed_hook('script.sed', 'input.file');

=head1 DESCRIPTION

Various hook routines for the test runners.

=cut

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      sed_hook
      sort_lines
      calibrate
      find_missing_prerequisites
    );
}

use Capture::Tiny qw(capture_merged);
use Carp;
use Const::Fast;
use Cwd qw(getcwd);
use File::Basename;
use File::Find::Rule;
use File::Path;
use File::stat;
use IPC::Run3;
use List::SomeUtils qw(any);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

const my $NEWLINE => qq{\n};
const my $WAIT_STATUS_SHIFT => 8;

=head1 FUNCTIONS

=over 4

=item sed_hook(SCRIPT, SUBJECT, OUTPUT)

Runs the parser sed on file SUBJECT using the instructions in SCRIPT
and places the result in the file OUTPUT.

=cut

sub sed_hook {
    my ($script, $path, $output) = @_;

    croak encode_utf8("Parser script $script does not exist.")
      unless -e $script;

    my @command = (qw{sed -r -f}, $script, $path);
    my $bytes;
    run3(\@command, \undef, \$bytes);
    my $status = ($? >> $WAIT_STATUS_SHIFT);

    croak encode_utf8("Hook failed: sed -ri -f $script $path > $output: $!")
      if $status;

    # already in bytes
    path($output)->spew($bytes);

    croak encode_utf8("Did not create parser output file $output.")
      unless -e $output;

    return $output;
}

=item sort_lines(UNSORTED, SORTED)

Sorts the file UNSORTED line by line and places the result into the
file SORTED.

=cut

sub sort_lines {
    my ($path, $sorted) = @_;

    open(my $rfd, '<', $path)
      or croak encode_utf8("Could not open pre-sort file $path: $!");
    my @lines = sort map { decode_utf8($_) } <$rfd>;
    close $rfd
      or carp encode_utf8("Could not close open pre-sort file $path: $!");

    open(my $wfd, '>', $sorted)
      or croak encode_utf8("Could not open sorted file $sorted: $!");
    print {$wfd} encode_utf8($_) for @lines;
    close $wfd
      or carp encode_utf8("Could not close sorted file $sorted: $!");

    return $sorted;
}

=item calibrate(SCRIPT, ACTUAL, EXPECTED, CALIBRATED)

Executes calibration script SCRIPT with the three arguments EXPECTED,
ACTUAL and CALIBRATED, all of which are file paths. Please note that
the order of arguments in this function corresponds to the
bookkeeping logic of ACTUAL vs EXPECTED. The order for the script is
different.

=cut

sub calibrate {
    my ($hook, $actual, $expected, $calibrated) = @_;

    if (-x $hook) {
        system($hook, $expected, $actual, $calibrated) == 0
          or croak encode_utf8("Hook $hook failed on $actual: $!");
        croak encode_utf8("No calibrated hints created in $calibrated")
          unless -e $calibrated;
        return $calibrated;
    }
    return $expected;
}

=item find_missing_prerequisites(TEST_CASE)

Returns a string with missing dependencies, if applicable, that would
be necessary to run the test described by hash DESC.

=cut

sub find_missing_prerequisites {
    my ($testcase) = @_;

    # without prerequisites, no need to look
    return undef
      unless any { $testcase->declares($_) }
    qw(Build-Depends Build-Conflicts Test-Depends Test-Conflicts);

    # create a temporary file
    my $temp = Path::Tiny->tempfile(
        TEMPLATE => 'lintian-test-build-depends-XXXXXXXXX');
    my @lines;

    # dpkg-checkbuilddeps requires a Source: field
    push(@lines, 'Source: bd-test-pkg');

    my $build_depends = join(
        ', ',
        grep { length }(
            $testcase->value('Build-Depends'),$testcase->value('Test-Depends'))
    );

    push(@lines, "Build-Depends: $build_depends")
      if length $build_depends;

    my $build_conflicts = join(
        ', ',
        grep { length }(
            $testcase->value('Build-Conflicts'),
            $testcase->value('Test-Conflicts')));
    push(@lines, "Build-Conflicts: $build_conflicts")
      if length $build_conflicts;

    $temp->spew_utf8(join($NEWLINE, @lines) . $NEWLINE);

    # run dpkg-checkbuilddeps
    my $command = "dpkg-checkbuilddeps $temp";
    my ($missing, $status) = capture_merged { system($command); };
    $status >>= $WAIT_STATUS_SHIFT;

    $missing = decode_utf8($missing)
      if length $missing;

    die encode_utf8("$command failed: $missing")
      if !$status && length $missing;

    # parse for missing prerequisites
    if ($missing =~ s{\A dpkg-checkbuilddeps: [ ] (?:error: [ ])? }{}xsm) {
        $missing =~ s{Unmet build dependencies}{Unmet}gi;
        chomp($missing);
        # expect exactly one line.
        die encode_utf8("Unexpected output from dpkg-checkbuilddeps: $missing")
          if $missing =~ s{\n}{\\n}gxsm;
        return $missing;
    }

    return undef;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

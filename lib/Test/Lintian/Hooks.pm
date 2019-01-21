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

use strict;
use warnings;
use autodie;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      sed_hook
      sort_lines
      calibrate
      find_missing_prerequisites
      run_lintian
    );
}

use Capture::Tiny qw(capture_merged);
use Carp;
use Cwd qw(getcwd);
use File::Basename;
use File::Find::Rule;
use File::Path;
use File::stat;
use Path::Tiny;
use File::Temp qw(tempfile);
use Text::Template;

use constant NEWLINE => qq{\n};
use constant SPACE => q{ };
use constant EMPTY => q{};
use constant SINGLEQ => q{'};

=head1 FUNCTIONS

=over 4

=item sed_hook(SCRIPT, SUBJECT, OUTPUT)

Runs the parser sed on file SUBJECT using the instructions in SCRIPT
and places the result in the file OUTPUT.

=cut

sub sed_hook {
    my ($script, $path, $output) = @_;

    croak "Parser script $script does not exist." unless -f $script;

    my $captured = qx(sed -r -f $script $path);
    croak "Hook failed: sed -ri -f $script $path > $output: $!" if $?;

    open(my $handle, '>', $output)
      or croak "Could not open file $output: $!";
    print {$handle} $captured;
    close($handle)
      or carp "Could not close file $output: $!";

    croak "Did not create parser output file $output." unless -f $output;

    return $output;
}

=item sort_lines(UNSORTED, SORTED)

Sorts the file UNSORTED line by line and places the result into the
file SORTED.

=cut

sub sort_lines {
    my ($path, $sorted) = @_;

    open(my $rfd, '<', $path)
      or croak "Could not open pre-sort file $path: $!";
    my @lines = sort(<$rfd>);
    close($rfd) or carp "Could not close open pre-sort file $path: $!";

    open(my $wfd, '>', $sorted)
      or croak "Could not open sorted file $sorted: $!";
    print {$wfd} $_ for @lines;
    close($wfd) or carp "Could not close sorted file $sorted: $!";

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
          or croak "Hook $hook failed on $actual: $!";
        croak "No calibrated tags created in $calibrated"
          unless -f $calibrated;
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

    # without prerequisites no need to look
    return
         unless $testcase->{build_depends}
      || $testcase->{build_conflicts}
      || $testcase->{test_depends}
      || $testcase->{test_conflicts};

    # create a temporary file
    my ($temphandle, $tempfile)= tempfile('bd-test-XXXXXXXXX', TMPDIR => 1);
    my @lines;

    # dpkg-checkbuilddeps requires a Source: field
    push(@lines, 'Source: bd-test-pkg');

    my $build_depends = join(', ',
        grep { $_ }
          ($testcase->{build_depends}//'',$testcase->{test_depends}//''));

    push(@lines, "Build-Depends: $build_depends")
      if length $build_depends;

    my $build_conflicts = join(', ',
        grep { $_ }
          ($testcase->{build_conflicts}//'',$testcase->{test_conflicts}//''));
    push(@lines, "Build-Conflicts: $build_conflicts")
      if length $build_conflicts;

    say {$temphandle} join(NEWLINE, @lines);
    close($temphandle) or carp "Could not close temporary file: $!";

    # run dpkg-checkbuilddeps
    my $command = "dpkg-checkbuilddeps $tempfile";
    my ($missing, $status) = capture_merged { system($command); };
    $status = ($status >> 8) & 255;

    # delete temporary file
    unlink($tempfile);

    die "$command failed: $missing" if !$status && length $missing;

    # parse for missing prerequisites
    if ($missing =~ s{\A dpkg-checkbuilddeps: [ ] (?:error: [ ])? }{}xsm) {
        $missing =~ s{Unmet build dependencies}{Unmet}gi;
        chomp($missing);
        # expect exactly one line.
        die "Unexpected output from dpkg-checkbuilddeps: $missing"
          if $missing =~ s{\n}{\\n}gxsm;
        return $missing;
    }

    return;
}

=item run_lintian(DESC, INPUT, INCLUDES, OUTPUT, DIR)

Runs Lintian in directory DIR on the input file INPUT and a collects the
output in file OUTPUT. Any include directories in INCLUDES, if present,
are passed on.

=cut

sub run_lintian {
    my ($directory, $subject, $profile, $includedir, $options, $product)= @_;

    my @cmd;

    # prepend some things for perl coverage
    push(@cmd,
        'perl', $ENV{'LINTIAN_COVERAGE'} . ",-db,$ENV{'LINTIAN_COVERDIR'}")
      if exists $ENV{'LINTIAN_COVERAGE'};

    # add lintan command
    push(@cmd, "cd $directory; $ENV{'LINTIAN_FRONTEND'}");

    # coverage has race conditions when using the same database
    push(@cmd, '-j1') if exists $ENV{LINTIAN_COVERAGE};

    # add other options
    push(@cmd, '--include-dir', $includedir) if -d $includedir;
    push(@cmd, '--no-user-dirs', '--profile', $profile);
    push(@cmd, '--allow-root', '--no-cfg');

    # properly escape any custom options
    my @customized = split(SPACE, $options);
    push(@cmd,
        SINGLEQ . join(SINGLEQ . SPACE . SINGLEQ, @customized) . SINGLEQ);

    # add file to be examined
    push(@cmd, basename($subject));

    # run lintian
    my $command = join(SPACE, @cmd);
    my ($output, $status) = capture_merged { system($command); };
    $status = ($status >> 8) & 255;

    my @lines = split(NEWLINE, $output);

    if (exists $ENV{LINTIAN_COVERAGE}) {
        # Devel::Cover causes deep recursion warnings.
        @lines = grep {
            !m{^Deep [ ] recursion [ ] on [ ] subroutine [ ]
           "[^"]+" [ ] at [ ] .*B/Deparse.pm [ ] line [ ]
           \d+}xsm
        } @lines;
    }

    unless ($status == 0 || $status == 1) {
        unshift(@lines, "$command exited with status $status");
        die join(NEWLINE, @lines);
    }

    # do not forget the final newline, or sorting will fail
    my $contents = scalar @lines ? join(NEWLINE, @lines) . NEWLINE : EMPTY;
    path($product)->spew($contents);

    return;
}

=back

=cut

1;


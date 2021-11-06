# Copyright © 2018 Felix Lechner
# Copyright © 2019 Chris Lamb <lamby@debian.org>
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

package Test::Lintian::Run;

=head1 NAME

Test::Lintian::Run -- generic runner for all suites

=head1 SYNOPSIS

  use Test::Lintian::Run qw(runner);

  my $runpath = "test working directory";

  runner($runpath);

=head1 DESCRIPTION

Generic test runner for all Lintian test suites

=cut

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      logged_runner
      runner
      check_result
    );
}

use Capture::Tiny qw(capture_merged);
use Const::Fast;
use Cwd qw(getcwd);
use File::Basename qw(basename);
use File::Spec::Functions qw(abs2rel rel2abs splitpath catpath);
use File::Compare;
use File::Copy;
use File::stat;
use IPC::Run3;
use List::Compare;
use List::Util qw(max min any all);
use Path::Tiny;
use Syntax::Keyword::Try;
use Test::More;
use Text::Diff;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Lintian::Deb822::File;
use Lintian::Profile;

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Helper qw(rfc822date);
use Test::Lintian::Hooks
  qw(find_missing_prerequisites sed_hook sort_lines calibrate);
use Test::Lintian::Output::Universal qw(get_tagnames order);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $INDENT => $SPACE x 2;
const my $SLASH => q{/};
const my $NEWLINE => qq{\n};
const my $YES => q{yes};
const my $NO => q{no};

const my $WAIT_STATUS_SHIFT => 8;

# turn off the @@-style headers in Text::Diff
no warnings 'redefine';
sub Text::Diff::Unified::file_header { return $EMPTY; }
sub Text::Diff::Unified::hunk_header { return $EMPTY; }

=head1 FUNCTIONS

=over 4

=item logged_runner(RUN_PATH)

Starts the generic test runner for the test located in RUN_PATH
and logs the output.

=cut

sub logged_runner {
    my ($runpath) = @_;

    my $error;

    # read dynamic file names
    my $runfiles = "$runpath/files";
    my $files = read_config($runfiles);

    # set path to logfile
    my $logpath = $runpath . $SLASH . $files->unfolded_value('Log');

    my $log_bytes = capture_merged {
        try {
            # call runner
            runner($runpath, $logpath)

        } catch {
            # catch any error
            $error = $@;
        }
    };

    my $log = decode_utf8($log_bytes);

    # append runner log to population log
    path($logpath)->append_utf8($log) if length $log;

    # add error if there was one
    path($logpath)->append_utf8($error) if length $error;

    # print log and die on error
    if ($error) {
        print encode_utf8($log)
          if length $log && $ENV{'DUMP_LOGS'}//$NO eq $YES;
        die encode_utf8("Runner died for $runpath: $error");
    }

    return;
}

=item runner(RUN_PATH)

This routine provides the basic structure for all runners and runs the
test located in RUN_PATH.

=cut

sub runner {
    my ($runpath, @exclude)= @_;

    # set a predictable locale
    $ENV{'LC_ALL'} = 'C';

    say encode_utf8($EMPTY);
    say encode_utf8('------- Runner starts here -------');

    # bail out if runpath does not exist
    BAIL_OUT(encode_utf8("Cannot find test directory $runpath."))
      unless -d $runpath;

    # announce location
    say encode_utf8("Running test at $runpath.");

    # read dynamic file names
    my $runfiles = "$runpath/files";
    my $files = read_config($runfiles);

    # get file age
    my $spec_epoch = stat($runfiles)->mtime;

    # read dynamic case data
    my $rundescpath
      = $runpath . $SLASH . $files->unfolded_value('Test-Specification');
    my $testcase = read_config($rundescpath);

    # get data age
    $spec_epoch = max(stat($rundescpath)->mtime, $spec_epoch);
    say encode_utf8('Specification is from : '. rfc822date($spec_epoch));

    say encode_utf8($EMPTY);

    # age of runner executable
    my $runner_epoch = $ENV{'RUNNER_EPOCH'}//time;
    say encode_utf8('Runner modified on   : '. rfc822date($runner_epoch));

    # age of harness executable
    my $harness_epoch = $ENV{'HARNESS_EPOCH'}//time;
    say encode_utf8('Harness modified on  : '. rfc822date($harness_epoch));

    # calculate rebuild threshold
    my $threshold= max($spec_epoch, $runner_epoch, $harness_epoch);
    say encode_utf8('Rebuild threshold is : '. rfc822date($threshold));

    say encode_utf8($EMPTY);

    # age of Lintian executable
    my $lintian_epoch = $ENV{'LINTIAN_EPOCH'}//time;
    say encode_utf8('Lintian modified on  : '. rfc822date($lintian_epoch));

    my $testname = $testcase->unfolded_value('Testname');
    # name of encapsulating directory should be that of test
    my $expected_name = path($runpath)->basename;
    die encode_utf8(
        "Test in $runpath is called $testname instead of $expected_name")
      unless $testname eq $expected_name;

    # skip test if marked
    my $skipfile = "$runpath/skip";
    if (-e $skipfile) {
        my $reason = path($skipfile)->slurp_utf8 || 'No reason given';
        say encode_utf8("Skipping test: $reason");
        plan skip_all => "(disabled) $reason";
    }

    # skip if missing prerequisites
    my $missing = find_missing_prerequisites($testcase);
    if (length $missing) {
        say encode_utf8("Missing prerequisites: $missing");
        plan skip_all => $missing;
    }

    # check test architectures
    unless (length $ENV{'DEB_HOST_ARCH'}) {
        say encode_utf8('DEB_HOST_ARCH is not set.');
        BAIL_OUT(encode_utf8('DEB_HOST_ARCH is not set.'));
    }
    my $platforms = $testcase->unfolded_value('Test-Architectures');
    if ($platforms ne 'any') {

        my @wildcards = split($SPACE, $platforms);
        my $match = 0;
        for my $wildcard (@wildcards) {

            my @command = (qw{dpkg-architecture -a},
                $ENV{'DEB_HOST_ARCH'}, '-i', $wildcard);
            run3(\@command, \undef, \undef, \undef);
            my $status = ($? >> $WAIT_STATUS_SHIFT);

            unless ($status) {
                $match = 1;
                last;
            }
        }
        unless ($match) {
            say encode_utf8('Architecture mismatch');
            plan skip_all => encode_utf8('Architecture mismatch');
        }
    }

    plan skip_all => 'No package found'
      unless -e "$runpath/subject";

    # set the testing plan
    plan tests => 1;

    my $subject = path("$runpath/subject")->realpath;

    # get lintian subject
    die encode_utf8('Could not get subject of Lintian examination.')
      unless -e $subject;

    # run lintian
    $ENV{'LINTIAN_COVERAGE'}.= ",-db,./cover_db-$testname"
      if exists $ENV{'LINTIAN_COVERAGE'};

    my $lintian_command_line
      = $testcase->unfolded_value('Lintian-Command-Line');
    my $command
      = "cd $runpath; $ENV{'LINTIAN_UNDER_TEST'} $lintian_command_line $subject";
    say encode_utf8($command);
    my ($output, $status) = capture_merged { system($command); };
    $status >>= $WAIT_STATUS_SHIFT;

    $output = decode_utf8($output)
      if length $output;

    say encode_utf8("$command exited with status $status.");
    say encode_utf8($output) if $status == 1;

    my $expected_status = $testcase->unfolded_value('Exit-Status');

    my @errors;
    push(@errors,
        "Exit code $status differs from expected value $expected_status.")
      if $testcase->declares('Exit-Status')
      && $status != $expected_status;

    # filter out some warnings if running under coverage
    my @lines = split(/\n/, $output);
    if (exists $ENV{LINTIAN_COVERAGE}) {
        # Devel::Cover causes deep recursion warnings.
        @lines = grep {
            !m{^Deep [ ] recursion [ ] on [ ] subroutine [ ]
           "[^"]+" [ ] at [ ] .*B/Deparse.pm [ ] line [ ]
           \d+}xsm
        } @lines;
    }

    # put output back together
    $output = $EMPTY;
    $output .= $_ . $NEWLINE for @lines;

    die encode_utf8('No match strategy defined')
      unless $testcase->declares('Match-Strategy');

    my $match_strategy = $testcase->unfolded_value('Match-Strategy');

    if ($match_strategy eq 'literal') {
        push(@errors, check_literal($testcase, $runpath, $output));

    } elsif ($match_strategy eq 'hints') {
        push(@errors, check_hints($testcase, $runpath, $output));

    } else {
        die encode_utf8("Unknown match strategy $match_strategy.");
    }

    my $okay = !(scalar @errors);

    if ($testcase->declares('Todo')) {

        my $explanation = $testcase->unfolded_value('Todo');
        diag "TODO ($explanation)";

      TODO: {
            local $TODO = $explanation;
            ok($okay, 'Lintian passes for test marked TODO.');
        }

        return;
    }

    diag $_ . $NEWLINE for @errors;

    ok($okay, "Lintian passes for $testname");

    return;
}

=item check_literal

=cut

sub check_literal {
    my ($testcase, $runpath, $output) = @_;

    # create expected output if it does not exist
    my $expected = "$runpath/literal";
    path($expected)->touch
      unless -e $expected;

    my $raw = "$runpath/literal.actual";
    path($raw)->spew_utf8($output);

    # run a sed-script if it exists
    my $actual = "$runpath/literal.actual.parsed";
    my $script = "$runpath/post-test";
    if (-e $script) {
        sed_hook($script, $raw, $actual);
    } else {
        die encode_utf8("Could not copy actual hints $raw to $actual: $!")
          if system('cp', '-p', $raw, $actual);
    }

    return check_result($testcase, $runpath, $expected, $actual);
}

=item check_hints

=cut

sub check_hints {
    my ($testcase, $runpath, $output) = @_;

    # create expected hints if there are none; helps when calibrating new tests
    my $expected = "$runpath/hints";
    path($expected)->touch
      unless -e $expected;

    my $raw = "$runpath/hints.actual";
    path($raw)->spew_utf8($output);

    # run a sed-script if it exists
    my $actual = "$runpath/hints.actual.parsed";
    my $sedscript = "$runpath/post-test";
    if (-e $sedscript) {
        sed_hook($sedscript, $raw, $actual);
    } else {
        die encode_utf8("Could not copy actual hints $raw to $actual: $!")
          if system('cp', '-p', $raw, $actual);
    }

    # calibrate hints; may write to $actual
    my $calibrated = "$runpath/hints.specified.calibrated";
    my $calscript = "$runpath/test-calibration";
    if(-x $calscript) {
        calibrate($calscript, $actual, $expected, $calibrated);
    } else {
        die encode_utf8(
            "Could not copy expected hints $expected to $calibrated: $!")
          if system('cp', '-p', $expected, $calibrated);
    }

    return check_result($testcase, $runpath, $calibrated, $actual);
}

=item check_result(DESC, EXPECTED, ACTUAL)

This routine checks if the EXPECTED hints match the calibrated ACTUAL for the
test described by DESC. For some additional checks, also need the ORIGINAL
hints before calibration. Returns a list of errors, if there are any.

=cut

sub check_result {
    my ($testcase, $runpath, $expectedpath, $actualpath) = @_;

    my @errors;

    my @expectedlines = path($expectedpath)->lines_utf8;
    my @actuallines = path($actualpath)->lines_utf8;

    push(@expectedlines, $NEWLINE)
      unless @expectedlines;
    push(@actuallines, $NEWLINE)
      unless @actuallines;

    my $match_strategy = $testcase->unfolded_value('Match-Strategy');

    if ($match_strategy eq 'hints') {
        @expectedlines
          = reverse sort { order($a) cmp order($b) } @expectedlines;
        @actuallines
          = reverse sort { order($a) cmp order($b) } @actuallines;
    }

    my $diff = diff(\@expectedlines, \@actuallines, { CONTEXT => 0 });
    my @difflines = split(/\n/, $diff);
    chomp @difflines;

    # diag "Difflines: $_" for @difflines;

    if(@difflines) {

        if ($match_strategy eq 'literal') {
            push(@errors, 'Literal output does not match');

        } elsif ($match_strategy eq 'hints') {

            push(@errors, 'Hints do not match');

            @difflines = reverse sort @difflines;
            my $hintdiff;
            $hintdiff .= $_ . $NEWLINE for @difflines;
            path("$runpath/hintdiff")->spew_utf8($hintdiff // $EMPTY);

        } else {
            die encode_utf8("Unknown match strategy $match_strategy.");
        }

        push(@errors, $EMPTY);

        push(@errors, '--- ' . abs2rel($expectedpath));
        push(@errors, '+++ ' . abs2rel($actualpath));
        push(@errors, @difflines);

        push(@errors, $EMPTY);
    }

    # stop if the test is not about hints
    return @errors
      unless $match_strategy eq 'hints';

    # get expected tags
    my @expected = sort +get_tagnames($expectedpath);

    #diag "=Expected tag: $_" for @expected;

    # look out for tags being tested
    my @related;

    if (   $testcase->declares('Check')
        && $testcase->unfolded_value('Check') ne 'all') {

        my $profile = Lintian::Profile->new;
        $profile->load(undef, undef, 0);

        # use tags related to checks declared
        my @check_names = $testcase->trimmed_list('Check');
        my @unknown
          = grep { !exists $profile->check_module_by_name->{$_} } @check_names;

        die encode_utf8('Unknown Lintian checks: ' . join($SPACE, @unknown))
          if @unknown;

        push(@related, @{$profile->tagnames_for_check->{$_} // []})
          for @check_names;

        @related = sort @related;

    } else {
        # otherwise, look for all expected tags
        @related = @expected;
    }

    #diag "#Related tag: $_" for @related;

    # calculate Test-For and Test-Against; results are sorted
    my $material = List::Compare->new(\@expected, \@related);
    my @test_for = $material->get_intersection;
    my @test_against = $material->get_Ronly;

    #diag "+Test-For: $_" for @test_for;
    #diag "-Test-Against (calculated): $_" for @test_against;

    # get actual tags from output
    my @actual = sort +get_tagnames($actualpath);

    #diag "*Actual tag found: $_" for @actual;

    # check for blacklisted tags; result is sorted
    my @unexpected
      = List::Compare->new(\@test_against, \@actual)->get_intersection;

    # warn about unexpected tags
    if (@unexpected) {
        push(@errors, 'Unexpected tags:');
        push(@errors, $INDENT . $_) for @unexpected;
        push(@errors, $EMPTY);
    }
    # find tags not seen; result is sorted
    my @missing = List::Compare->new(\@test_for, \@actual)->get_Lonly;

    # warn about missing tags
    if (@missing) {
        push(@errors, 'Missing tags:');
        push(@errors, $INDENT . $_) for @missing;
        push(@errors, $EMPTY);
    }

    return @errors;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

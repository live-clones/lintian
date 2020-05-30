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
use autodie;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      logged_runner
      runner
      check_result
    );
}

use Capture::Tiny qw(capture_merged);
use Cwd qw(getcwd);
use File::Basename qw(basename);
use File::Spec::Functions qw(abs2rel rel2abs splitpath catpath);
use File::Compare;
use File::Copy;
use File::stat;
use List::Compare;
use List::Util qw(max min any all);
use Path::Tiny;
use Test::More;
use Text::Diff;
use Try::Tiny;

use Lintian::Profile;

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Helper qw(rfc822date);
use Test::Lintian::Hooks
  qw(find_missing_prerequisites sed_hook sort_lines calibrate);
use Test::Lintian::Output::Universal qw(get_tagnames order);

use constant SPACE => q{ };
use constant EMPTY => q{};
use constant NEWLINE => qq{\n};
use constant YES => q{yes};
use constant NO => q{no};

# turn off the @@-style headers in Text::Diff
no warnings 'redefine';
sub Text::Diff::Unified::file_header { return EMPTY; }
sub Text::Diff::Unified::hunk_header { return EMPTY; }

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
    my $logpath = "$runpath/$files->{log}";

    my $log = capture_merged {
        try {
            # call runner
            runner($runpath, $logpath)

        }catch {
            # catch any error
            $error = $_;
        };
    };

    # append runner log to population log
    path($logpath)->append_utf8($log) if length $log;

    # add error if there was one
    path($logpath)->append_utf8($error) if length $error;

    # print log and die on error
    if ($error) {
        print $log if length $log && $ENV{'DUMP_LOGS'}//NO eq YES;
        die "Runner died for $runpath: $error";
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

    # many tests create files via debian/rules
    umask(022);

    say EMPTY;
    say '------- Runner starts here -------';

    # bail out if runpath does not exist
    BAIL_OUT("Cannot find test directory $runpath.") unless -d $runpath;

    # announce location
    say "Running test at $runpath.";

    # read dynamic file names
    my $runfiles = "$runpath/files";
    my $files = read_config($runfiles);

    # get file age
    my $spec_epoch = stat($runfiles)->mtime;

    # read dynamic case data
    my $rundescpath = "$runpath/$files->{test_specification}";
    my $testcase = read_config($rundescpath);

    # get data age
    $spec_epoch = max(stat($rundescpath)->mtime, $spec_epoch);
    say 'Specification is from : '. rfc822date($spec_epoch);

    say EMPTY;

    # age of runner executable
    my $runner_epoch = $ENV{'RUNNER_EPOCH'}//time;
    say 'Runner modified on   : '. rfc822date($runner_epoch);

    # age of harness executable
    my $harness_epoch = $ENV{'HARNESS_EPOCH'}//time;
    say 'Harness modified on  : '. rfc822date($harness_epoch);

    # calculate rebuild threshold
    my $threshold= max($spec_epoch, $runner_epoch, $harness_epoch);
    say 'Rebuild threshold is : '. rfc822date($threshold);

    say EMPTY;

    # age of Lintian executable
    my $lintian_epoch = $ENV{'LINTIAN_EPOCH'}//time;
    say 'Lintian modified on  : '. rfc822date($lintian_epoch);

    # name of encapsulating directory should be that of test
    my $expected_name = path($runpath)->basename;
    die
"Test in $runpath is called $testcase->{testname} instead of $expected_name"
      if ($testcase->{testname} ne $expected_name);

    # skip test if marked
    my $skipfile = "$runpath/skip";
    if (-f $skipfile) {
        my $reason = path($skipfile)->slurp_utf8 || 'No reason given';
        say "Skipping test: $reason";
        plan skip_all => "(disabled) $reason";
    }

    # skip if missing prerequisites
    my $missing = find_missing_prerequisites($testcase);
    if (length $missing) {
        say "Missing prerequisites: $missing";
        plan skip_all => $missing;
    }

    # check test architectures
    unless (length $ENV{'DEB_HOST_ARCH'}) {
        say 'DEB_HOST_ARCH is not set.';
        BAIL_OUT('DEB_HOST_ARCH is not set.');
    }
    my $platforms = $testcase->{test_architectures};
    if ($platforms ne 'any') {
        my @wildcards = split(SPACE, $platforms);
        my @matches= map {
            qx{dpkg-architecture -a $ENV{'DEB_HOST_ARCH'} -i $_; echo -n \$?}
        } @wildcards;
        unless (any { $_ == 0 } @matches) {
            say 'Architecture mismatch';
            plan skip_all => 'Architecture mismatch';
        }
    }

    plan skip_all => 'No package found'
      unless -f "$runpath/subject";

    # set the testing plan
    plan tests => 1;

    my $subject = path("$runpath/subject")->realpath;

    # get lintian subject
    die 'Could not get subject of Lintian examination.'
      unless -f $subject;

    # run lintian
    $ENV{'LINTIAN_COVERAGE'}.= ",-db,./cover_db-$testcase->{testname}"
      if exists $ENV{'LINTIAN_COVERAGE'};

    my $command
      = "cd $runpath; $ENV{'LINTIAN_FRONTEND'} $testcase->{lintian_command_line} $subject";
    say $command;
    my ($output, $status) = capture_merged { system($command); };
    $status = ($status >> 8) & 255;

    say "$command exited with status $status.";
    say $output if $status == 1;

    my @errors;
    push(@errors,
"Exit code $status differs from expected value $testcase->{exit_status}."
      )
      if defined $testcase->{exit_status}
      && $status != $testcase->{exit_status};

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
    $output = EMPTY;
    $output .= $_ . NEWLINE for @lines;

    die 'No match strategy defined'
      unless length $testcase->{match_strategy};

    if ($testcase->{match_strategy} eq 'literal') {
        push(@errors, check_literal($testcase, $runpath, $output));
    } elsif ($testcase->{match_strategy} eq 'tags') {
        push(@errors, check_tags($testcase, $runpath, $output));
    } else {
        die "Unknown match strategy $testcase->{match_strategy}.";
    }

    my $okay = !(scalar @errors);

    if($testcase->{todo} eq 'yes') {
      TODO: {
            local $TODO = 'Test marked as TODO.';
            ok($okay, 'Lintian passes for test marked TODO.');
        }
        return;
    }

    diag $_ . NEWLINE for @errors;

    ok($okay, "Lintian passes for $testcase->{testname}");

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
    path($raw)->spew($output);

    # run a sed-script if it exists
    my $actual = "$runpath/literal.actual.parsed";
    my $script = "$runpath/post-test";
    if(-f $script) {
        sed_hook($script, $raw, $actual);
    } else {
        die"Could not copy actual tags $raw to $actual: $!"
          if(system('cp', '-p', $raw, $actual));
    }

    return check_result($testcase, $runpath, $expected, $actual);
}

=item check_tags

=cut

sub check_tags {
    my ($testcase, $runpath, $output) = @_;

    # create expected tags if there are none; helps when calibrating new tests
    my $expected = "$runpath/tags";
    path($expected)->touch
      unless -e $expected;

    my $raw = "$runpath/tags.actual";
    path($raw)->spew($output);

    # run a sed-script if it exists
    my $actual = "$runpath/tags.actual.parsed";
    my $sedscript = "$runpath/post-test";
    if(-f $sedscript) {
        sed_hook($sedscript, $raw, $actual);
    } else {
        die"Could not copy actual tags $raw to $actual: $!"
          if(system('cp', '-p', $raw, $actual));
    }

    # calibrate tags; may write to $actual
    my $calibrated = "$runpath/tags.specified.calibrated";
    my $calscript = "$runpath/test-calibration";
    if(-x $calscript) {
        calibrate($calscript, $actual, $expected, $calibrated);
    } else {
        die"Could not copy expected tags $expected to $calibrated: $!"
          if(system('cp', '-p', $expected, $calibrated));
    }

    return check_result($testcase, $runpath, $calibrated, $actual);
}

=item check_result(DESC, EXPECTED, ACTUAL)

This routine checks if the EXPECTED tags match the calibrated ACTUAL for the
test described by DESC. For some additional checks, also need the ORIGINAL
tags before calibration. Returns a list of errors, if there are any.

=cut

sub check_result {
    my ($testcase, $runpath, $expectedpath, $actualpath) = @_;

    my @errors;

    my @expectedlines = path($expectedpath)->lines;
    my @actuallines = path($actualpath)->lines;

    push(@expectedlines, NEWLINE)
      unless @expectedlines;
    push(@actuallines, NEWLINE)
      unless @actuallines;

    if ($testcase->{match_strategy} eq 'tags') {
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

        if ($testcase->{match_strategy} eq 'literal') {
            push(@errors, 'Literal output does not match');

        } elsif ($testcase->{match_strategy} eq 'tags') {

            push(@errors, 'Tags do not match');

            @difflines = reverse sort @difflines;
            my $tagdiff;
            $tagdiff .= $_ . NEWLINE for @difflines;
            path("$runpath/tagdiff")->spew($tagdiff // EMPTY);

        } else {
            die "Unknown match strategy $testcase->{match_strategy}.";
        }

        push(@errors, EMPTY);

        push(@errors, '--- ' . abs2rel($expectedpath));
        push(@errors, '+++ ' . abs2rel($actualpath));
        push(@errors, @difflines);

        push(@errors, EMPTY);
    }

    # stop if the test is not about tags
    return @errors
      unless $testcase->{match_strategy} eq 'tags';

    # get expected tags
    my @expected = sort +get_tagnames($expectedpath);

    #diag "=Expected tag: $_" for @expected;

    # look out for tags being tested
    my @related;

    if (length $testcase->{check} && $testcase->{check} ne 'all') {

        my $profile = Lintian::Profile->new;
        $profile->load(undef, [$ENV{LINTIAN_ROOT}]);

        # use tags related to checks declared
        my @checks = split(SPACE, $testcase->{check});
        foreach my $check (@checks) {
            my $checkscript = $profile->get_checkinfo($check);
            die "Unknown Lintian check $check"
              unless defined $checkscript;

            push(@related, $checkscript->tags);
        }

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
        push(@errors, SPACE . SPACE . $_) for @unexpected;
        push(@errors, EMPTY);
    }
    # find tags not seen; result is sorted
    my @missing = List::Compare->new(\@test_for, \@actual)->get_Lonly;

    # warn about missing tags
    if (@missing) {
        push(@errors, 'Missing tags:');
        push(@errors, SPACE . SPACE . $_) for @missing;
        push(@errors, EMPTY);
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

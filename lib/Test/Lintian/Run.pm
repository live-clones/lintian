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

use strict;
use warnings;
use autodie;
use v5.10;

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
use List::Util qw(max min any);
use Path::Tiny;
use Test::More;
use Text::CSV;
use Try::Tiny;

use Lintian::Command qw(safe_qx);

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Helper qw(rfc822date);
use Test::Lintian::Hooks
  qw(find_missing_prerequisites run_lintian sed_hook sort_lines calibrate);
use Test::Lintian::Prepare qw(early_logpath);
use Test::StagedFileProducer;

use constant SPACE => q{ };
use constant EMPTY => q{};
use constant NEWLINE => qq{\n};
use constant YES => q{yes};
use constant NO => q{no};

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
    my $betterlogpath = "$runpath/$files->{log}";

    my $log = capture_merged {
        try {
            # call runner
            runner($runpath, $betterlogpath)

        }
        catch {
            # catch any error
            $error = $_;
        };
    };

    # delete old runner log
    unlink $betterlogpath if -f $betterlogpath;

    # move the early log for directory preparation to position of runner log
    my $earlylogpath = early_logpath($runpath);
    move($earlylogpath, $betterlogpath) if -f $earlylogpath;

    # append runner log to population log
    path($betterlogpath)->append_utf8($log) if length $log;

    # add error if there was one
    path($betterlogpath)->append_utf8($error) if length $error;

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

    # set the testing plan
    plan tests => 1;

    my $producer = Test::StagedFileProducer->new(path => $runpath);
    $producer->exclude(@exclude);

    # get lintian subject
    die 'Could not get subject of Lintian examination.'
      unless exists $testcase->{build_product};
    my $subject = "$runpath/$testcase->{build_product}";

    # build subject for lintian examination
    $producer->add_stage(
        products => [$subject],
        minimum_epoch => $threshold,
        build =>sub {
            if(exists $testcase->{build_command}) {
                my $command= "cd $runpath; $testcase->{build_command}";
                die "$command failed" if system($command);
            }

            die 'Build was unsuccessful.'
              unless -f $subject;
        });

    # run lintian
    my $actual = "$runpath/tags.actual";
    $producer->add_stage(
        products => [$actual],
        minimum_epoch => $lintian_epoch,
        build =>sub {
            $ENV{'LINTIAN_COVERAGE'}.= ",-db,./cover_db-$testcase->{testname}"
              if exists $ENV{'LINTIAN_COVERAGE'};

            my $lintian = read_config("$runpath/lintian-command");
            my $command
              = "cd $runpath; $ENV{'LINTIAN_FRONTEND'} $lintian->{options} $lintian->{subject}";
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
            my $contents
              = scalar @lines ? join(NEWLINE, @lines) . NEWLINE : EMPTY;
            path($actual)->spew($contents);
        });

    # run a sed-script if it exists
    my $parsed = "$runpath/tags.actual.parsed";
    $producer->add_stage(
        products => [$parsed],
        build =>sub {
            my $script = "$runpath/post_test";
            if(-f $script) {
                sed_hook($script, $actual, $parsed);
            } else {
                die"Could not copy actual tags $actual to $parsed: $!"
                  if(system('cp', '-p', $actual, $parsed));
            }
        });

    # sort tags
    my $sorted = "$runpath/tags.actual.parsed.sorted";
    $producer->add_stage(
        products => [$sorted],
        build =>sub {
            if($testcase->{sort} eq 'yes') {
                sort_lines($parsed, $sorted);
            } else {
                die"Could not copy parsed tags $parsed to $sorted: $!"
                  if(system('cp', '-p', $parsed, $sorted));
            }
        });

    my $specified = "$runpath/tags";

    # calibrate tags; may write to $sorted
    my $calibrated = "$runpath/tags.specified.calibrated";
    $producer->add_stage(
        products => [$calibrated],
        build =>sub {
            my $script = "$runpath/test_calibration";
            if(-x $script) {
                calibrate($script, $sorted, $specified, $calibrated);
            } else {
                die"Could not copy expected tags $specified to $calibrated: $!"
                  if(system('cp', '-p', $specified, $calibrated));
            }
        });

    # extract expected tags
    my $expected = "$runpath/tags.specified.calibrated.extracted";
    $producer->add_stage(
        products => [$expected],
        build =>sub {
            my @command = ('tagextract', '-f', 'EWI', $calibrated, $expected);
            die 'Error executing: ' . join(SPACE, @command) . ": $!"
              if system(@command);
        });

    # extract actual tags
    my $extracted = "$runpath/tags.actual.parsed.sorted.extracted";
    $producer->add_stage(
        products => [$extracted],
        build =>sub {
            my @command = (
                'tagextract', '-f', $testcase->{output_format},
                $sorted, $extracted
            );
            die 'Error executing: ' . join(SPACE, @command) . ": $!"
              if system(@command);
        });

    say EMPTY;
    $producer->run(verbose => 1);

    my @errors = check_result($testcase, $extracted, $expected, $specified);

    my $okay = !scalar @errors;

    if($testcase->{todo} eq 'yes') {
      TODO: {
            local $TODO = 'Test marked as TODO.';
            ok($okay, 'Lintian tags match for test marked TODO.');
        }
        return;
    }

    ok($okay, "Lintian tags match for $testcase->{testname}");

    diag $_ . NEWLINE for @errors;

    #    for uncalibrated tests, use tags in spec path, for cut & paste
    #      $expected = rel2abs("$testcase->{spec_path}/tags")
    #      unless -e "$runpath/test_calibration";

    unless($okay) {
        my @command = ('tagdiff', $expected, $extracted);
        my ($diff, $status) = capture_merged { system(@command); };
        $status = ($status >> 8) & 255;
        die 'Error executing: ' . join(SPACE, @command) . ": $!"
          if $status;

        if (length $diff) {
            diag '--- ' . abs2rel($expected);
            diag '+++ ' . abs2rel($extracted);
            diag $diff;
        }
    }

    return;
}

=item check_result(DESC, ACTUAL, EXPECTED, ORIGINAL)

This routine checks if the EXPECTED tags match the calibrated ACTUAL for the
test described by DESC. For some additional checks, also need the ORIGINAL
tags before calibration. Returns a list of errors, if there are any.

=cut

sub check_result {
    my ($testcase, $actual, $expected, $originaltags) = @_;

    # fail if tags do not match
    return 'Tags do not match' if (compare($actual, $expected) != 0);

    # check all Test-For tags were seen and all Test-Against tags were not
    my %test_for = map { $_ => 1 } split SPACE, $testcase->{test_for}//EMPTY;
    my %test_against =map { $_ => 1 } split SPACE,
      $testcase->{test_against}//EMPTY;

    return unless (%test_for || %test_against);

    my @errors;

    my $csv = Text::CSV->new({ sep_char => '|' });

    # look through actual tags
    my @lines = path($actual)->lines_utf8({ chomp => 1 });
    foreach my $line (@lines) {

        my $status = $csv->parse($line);
        die "Cannot parse line $line: " . $csv->error_diag
          unless $status;
        my ($type, $package, $name, $details) = $csv->fields;

        unless (length $type && length $package && length $name) {
            push(@errors, "Invalid line in $actual: $line");
            next;
        }

        # check if tag was blacklisted
        if ($test_against{$name}) {

            # warn just once about a tag
            delete $test_against{$name};
            push(@errors, "Tag $name seen but listed in Test-Against");
        }

        # mark as seen
        delete $test_for{$name};
    }

    # check if test was calibrated
    if (defined $originaltags && compare($originaltags, $expected) != 0) {

        # tags lost in calibration; like binaries-hardening on some arches
        my %lost;

        # parse expected tags
        my @lines = path($expected)->lines_utf8({ chomp => 1 });
        foreach my $line (@lines) {

            my $status = $csv->parse($line);
            die "Cannot parse line $line: " . $csv->error_diag
              unless $status;
            my ($type, $package, $name, $details) = $csv->fields;

            unless (length $type && length $package && length $name) {
                push(@errors, "Invalid line in $expected: $line");
                next;
            }

            # mark as seen
            $lost{$name} = 1;
        }

        # parse original expected tags
        my @origlines = path($originaltags)->lines_utf8({ chomp => 1 });
        foreach my $line (@origlines) {

            # not tag in this line
            next if $line =~ /^N: /;

            # some traversal tests create packages that are skipped
            next if $line =~ /tainted/ && $line =~ /skipping/;

            # look for "EWI: package[ type]: tag"
            my ($name)
              = $line =~ /^.: \S+(?: (?:changes|source|udeb))?: (\S+)/o;
            unless (length $name) {
                push(@errors, "Invalid line: $line");
                next;
            }
            delete $lost{$name};
        }

        # remove tags that were calibrated out
        foreach my $name (keys %lost) {
            delete $test_for{$name};
        }
    }

    # check if the test missed any tags
    for my $name (sort keys %test_for) {
        push(@errors, "Tag $name listed in Test-For but not found");
    }

    return @errors;
}

=back

=cut

1;

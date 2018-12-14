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
      runner
      check_result
    );
}

use Carp qw(confess);
use Cwd qw(getcwd);
use File::Basename qw(basename);
use File::Path qw(make_path);
use File::Spec::Functions qw(abs2rel rel2abs splitpath catpath);
use File::Compare;
use File::Copy;
use File::stat;
use List::Util qw(max min any);
use Path::Tiny;

use Lintian::Command qw(safe_qx);
use Lintian::Util qw(internal_error touch_file);

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Harness qw(runsystem_ok up_to_date);
use Test::Lintian::Helper qw(rfc822date);

use constant SPACE => q{ };
use constant EMPTY => q{};
use constant YES => q{yes};
use constant NO => q{no};

# generic_runner
#
# Runs the test called $test assumed to be located in $testset/$dir/$test/.
#
sub runner {
    my ($test_state, $testcase, $outpath, $testset, $dump_logs, $coverage)= @_;

    my $suite = $testcase->{suite};
    my $testname = $testcase->{testname};
    my $specpath = "$testset/$suite/$testname";

    my $runpath = "$outpath/$suite/$testname";

    # get lintian subject
    die 'Could not get subject of Lintian examination.'
      unless exists $testcase->{build_product};
    my $subject = "$runpath/$testcase->{build_product}";

    $test_state->progress('building');

    if (exists $testcase->{build_command}) {
        my $command
          = "cd $runpath; $testcase->{build_command} > ../build.$testname 2>&1";
        if (system($command)) {
            $test_state->dump_log("${outpath}/${suite}/build.${testname}")
              if $dump_logs;
            die "$command failed.";
        }
    }

    die 'Build was unsuccessful.'
      unless -f $subject;

    my $pkg = $testcase->{source};

    run_lintian($test_state, $testcase, $subject, $runpath,
        "$runpath/tags.$pkg", $coverage);

    # Run a sed-script if it exists, for tests that have slightly variable
    # output
    if (-f "$runpath/post_test") {
        runsystem_ok('sed', '-ri', '-f', "$runpath/post_test",
            "$runpath/tags.$pkg");
        if ($testcase->{'sort'} eq 'yes') {
            # Re-sort as the sed may have changed the order lines
            open(my $rfd, '<', "$runpath/tags.$pkg");
            my @lines = sort(<$rfd>);
            close($rfd);
            open(my $wfd, '>', "$runpath/tags.$pkg");
            print {$wfd} $_ for @lines;
            close($wfd);
        }
    }

    my $expected = "$specpath/tags";
    my $origexp = $expected;

    if (-x "$runpath/test_calibration") {
        my $calibrated = "$runpath/expected.$pkg.calibrated";
        $test_state->progress('test_calibration hook');
        runsystem_ok(
            "$runpath/test_calibration", $expected,
            "$runpath/tags.$pkg", $calibrated
        );
        $expected = $calibrated if -e $calibrated;
    }

    check_result($test_state, $testcase, $expected,
        "$runpath/tags.$pkg",$origexp);

    return;
}

sub run_lintian {
    my ($test_state, $testcase, $file, $rundir, $out, $coverage) = @_;
    $test_state->progress('testing');
    my @options = split(' ', $testcase->{options}//'');
    unshift(@options, '--allow-root', '--no-cfg');
    unshift(@options, '--profile', $testcase->{profile});
    unshift(@options, '--no-user-dirs');
    if (my $incl_dir = $testcase->{'lintian_include_dir'}) {
        unshift(@options, '--include-dir', $incl_dir);
    }
    my $pid = open(my $in, '-|');
    if ($pid) {
        my @data = <$in>;
        my $status = 0;
        eval {close($in);};
        if (my $err = $@) {
            internal_error("close pipe: $!") if $err->errno;
            $status = ($? >> 8) & 255;
        }
        if (defined($coverage)) {
            # Devel::Cover causes some annoying deep recursion
            # warnings.  Filter them out, but only during coverage.
            # - This is not flawless, but it gets most of them
            @data = grep {
                !m{^Deep [ ] recursion [ ] on [ ] subroutine [ ]
                    "[^"]+" [ ] at [ ] .*B/Deparse.pm [ ] line [ ]
                   \d+}xsm
            } @data;
        }
        unless ($status == 0 or $status == 1) {
            my $name = $testcase->{testname};
            #NB: lines in @data have trailing newlines.
            my $msg
              = "$ENV{'LINTIAN_FRONTEND'} @options $file exited with status $status\n";
            $msg .= join(q{},map { "$name: $_" } @data);

            die $msg;
        } else {
            @data = sort @data if $testcase->{sort} eq 'yes';
            open(my $fd, '>', $out);
            print $fd $_ for @data;
            close($fd);
        }
    } else {
        my @LINTIAN_CMD = ($ENV{'LINTIAN_FRONTEND'});
        my @LINTIAN_COMMON_OPTIONS;

        my @cmd = @LINTIAN_CMD;

        if (defined($coverage)) {
            my $harness_perl_switches = $ENV{'HARNESS_PERL_SWITCHES'}//'';
            # Only collect coverage for stuff that D::NYTProf and
            # Test::Pod::Coverage cannot do for us.  This makes cover use less
            # RAM in the other end.
            my @criteria = qw(statement branch condition path subroutine);
            my $coverage_arg
              = '-MDevel::Cover=-silent,1,+ignore,^(.*/)?t/scripts/.+';
            $coverage_arg .= ',+ignore,/usr/bin/.*,+ignore,(.*/)?Dpkg';
            $coverage_arg .= ',-coverage,' . join(',-coverage,', @criteria);
            $coverage_arg .= ',' . $coverage if $coverage ne '';
            $ENV{'LINTIAN_COVERAGE'} = $coverage_arg;
            $harness_perl_switches .= ' ' . $coverage_arg;
            $ENV{'HARNESS_PERL_SWITCHES'} = $harness_perl_switches;
            # Coverage has some race conditions (at least when using the same
            # cover database).
            push(@LINTIAN_COMMON_OPTIONS, '-j1');
        }

        if ($ENV{'LINTIAN_COVERAGE'}) {
            my $suite = $testcase->{suite};
            my $name = $testcase->{testname};
            my $cover_dir = "./cover_db-${suite}-${name}";
            $ENV{'LINTIAN_COVERAGE'} .= ",-db,${cover_dir}";
            unshift(@cmd, 'perl', $ENV{'LINTIAN_COVERAGE'});
        }
        open(STDERR, '>&', \*STDOUT);
        chdir($rundir);
        exec @cmd, @options, @LINTIAN_COMMON_OPTIONS, $file
          or internal_error("exec failed: $!");
    }
    return 1;
}

sub check_result {
    my ($test_state, $testcase, $expected, $actual, $origexp) = @_;
    # Compare the output to the expected tags.
    my $testok = runsystem_ok('cmp', '-s', $expected, $actual);

    if (not $testok) {
        if ($testcase->{'todo'} eq 'yes') {
            $test_state->pass_todo_test('failed but marked as TODO');
            return;
        } else {
            $test_state->diff_files($expected, $actual);
            $test_state->fail_test('output differs!');
            return;
        }
    }

    unless ($testcase) {
        $test_state->pass_test;
        return;
    }

    # Check the output for invalid lines.  Also verify that all Test-For tags
    # are seen and all Test-Against tags are not.  Skip this part of the test
    # if neither Test-For nor Test-Against are set and Sort is also not set,
    # since in that case we probably have non-standard output.
    my %test_for = map { $_ => 1 } split(' ', $testcase->{'test_for'}//'');
    my %test_against
      = map { $_ => 1 } split(' ', $testcase->{'test_against'}//'');
    if (    not %test_for
        and not %test_against
        and $testcase->{'output_format'} ne 'EWI') {
        if ($testcase->{'todo'} eq 'yes') {
            $test_state->fail_test('marked as TODO but succeeded');
            return;
        } else {
            $test_state->pass_test;
            return;
        }
    } else {
        my $okay = 1;
        my @msgs;
        open(my $etags, '<', $actual);
        while (<$etags>) {
            next if m/^N: /;
            # Some of the traversal tests creates packages that are
            # skipped; accept that in the output
            next if m/tainted/o && m/skipping/o;
            # Looks for "$code: $package[ $type]: $tag"
            if (not /^.: \S+(?: (?:changes|source|udeb))?: (\S+)/o) {
                chomp;
                push(@msgs, "Invalid line: $_");
                $okay = 0;
                next;
            }
            my $tag = $1;
            if ($test_against{$tag}) {
                push(@msgs, "Tag $tag seen but listed in Test-Against");
                $okay = 0;
                # Warn only once about each "test-against" tag
                delete $test_against{$tag};
            }
            delete $test_for{$tag};
        }
        close($etags);
        if (%test_for) {
            if ($origexp && $origexp ne $expected) {
                # Test has been calibrated, check if some of the
                # "Test-For" has been calibrated out.  (Happens with
                # binaries-hardening on some architectures).
                open(my $oe, '<', $expected);
                my %cp_tf = %test_for;
                while (<$oe>) {
                    next if m/^N: /;
                    # Some of the traversal tests creates packages that are
                    # skipped; accept that in the output
                    next if m/tainted/o && m/skipping/o;
                    if (not /^.: \S+(?: (?:changes|source|udeb))?: (\S+)/o) {
                        chomp;
                        push(@msgs, "Invalid line: $_");
                        $okay = 0;
                        next;
                    }
                    delete $cp_tf{$1};
                }
                close($oe);
                # Remove tags that has been calibrated out.
                foreach my $tag (keys %cp_tf) {
                    delete $test_for{$tag};
                }
            }
            for my $tag (sort keys %test_for) {
                push(@msgs, "Tag $tag listed in Test-For but not found");
                $okay = 0;
            }
        }
        if ($okay) {
            if ($testcase->{'todo'} eq 'yes') {
                $test_state->fail_test('marked as TODO but succeeded');
                return;
            }
            $test_state->pass_test;
            return;
        } elsif ($testcase->{'todo'} eq 'yes') {
            $test_state->pass_todo_test(join("\n", @msgs));
            return;
        } else {
            $test_state->fail_test(join("\n", @msgs));
            return;
        }
    }
    confess("Assertion: This should be unreachable\n");
}

1;


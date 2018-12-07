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

package Test::Lintian::Prepare;

=head1 NAME

Test::Lintian::Prepare -- routines to prepare the work directories

=head1 SYNOPSIS

  use Test::Lintian::Prepare qw(prepare);

=head1 DESCRIPTION

The routines in this module prepare the work directories in which the
tests are run. To do so, they use the specifications in the test set.

=cut

use strict;
use warnings;
use autodie;
use v5.10;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      prepare
    );
}

use Cwd qw(getcwd);
use File::Copy;
use File::Find::Rule;
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(abs2rel rel2abs splitpath splitdir catpath);
use File::stat;
use List::MoreUtils qw(any);
use List::Util qw(max);
use Path::Tiny;

use Lintian::Command qw(safe_qx);

use Test::Lintian::ConfigFile qw(read_config write_config);
use Test::Lintian::Harness
  qw(check_test_depends runsystem_ok skip_reason up_to_date);
use Test::Lintian::Helper qw(rfc822date copy_dir_contents);
use Test::Lintian::Templates
  qw(copy_skeleton_template_sets remove_surplus_templates fill_skeleton_templates fill_template);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COMMA => q{,};

# prepare
#
# Prepares the test called $test assumed to be located in $TESTSET/$dir/$test/.
#
sub prepare {
    my (
        $test_state, $testdata, $RUNDIR,
        $TESTSET, $RUNNER_TS, $ALWAYS_REBUILD,
        $ARCHITECTURE, $STANDARDS_VERSION, $DATE
    ) = @_;
    my $suite = $testdata->{suite};
    my $testname = $testdata->{testname};
    my $testdir = "$TESTSET/$suite/$testname";

    unless ($testdata->{testname} && exists $testdata->{version}) {
        die 'Name or Version missing';
    }

    $testdata->{source} ||= $testdata->{testname};

    $testdata->{date} ||= $DATE;

    if (not $testdata->{prev_version}) {
        $testdata->{prev_version} = '0.0.1';
        $testdata->{prev_version} .= '-1'
          if index($testdata->{version}, '-') > -1;
    }

    $testdata->{host_architecture} = $ARCHITECTURE;
    $testdata->{'standards_version'} ||= $STANDARDS_VERSION;

    $testdata->{'dh_compat_level'} //= '11';

    $testdata->{'default_build_depends'}
      //= "debhelper (>= $testdata->{dh_compat_level}~)";

    $testdata->{'build_depends'} ||= join(
        ', ',
        grep { $_ }(
            $testdata->{'default_build_depends'},
            $testdata->{'extra_build_depends'}));

    # Check for arch-specific tests
    if ($testdata->{'test_architectures'} ne 'any') {
        my @wildcards = split(/\s+/,$testdata->{'test_architectures'});
        my @matches
          = map { qx{dpkg-architecture -i $_; echo -n \$?} } @wildcards;
        unless (any { $_ == 0 } @matches) {
            $test_state->skip_test('architecture mismatch');
            return 1;
        }
    }

    if ($testdir and -d "${testdir}/lintian-include-dir") {
        $testdata->{'lintian_include_dir'} = './lintian-include-dir';
    }

    $testdata->{upstream_version} = $testdata->{version};
    $testdata->{upstream_version} =~ s/-[^-]+$//;
    $testdata->{upstream_version} =~ s/(-|^)(\d+):/$1/;

    my $epochless_version = $testdata->{version};
    $epochless_version =~ s/^\d+://;
    $testdata->{no_epoch} = $epochless_version;

    $test_state->progress('setup');

    my $targetdir = "$RUNDIR/$suite/$testname";
    my $stampfile = "$RUNDIR/$suite/$testname-build-stamp";

    if (-f "$testdir/skip") {
        my $reason = skip_reason("$testdir/skip");
        $test_state->skip_test("(disabled) $reason");
        return 1;
    }

    die 'Outdated test specification (./debian/debian exists).'
      if -e "$testdir/debian/debian";

    if (   $testdata->{'test_depends'}
        || $testdata->{'test_conflicts'}
        || $testdata->{'build_depends'}
        || $testdata->{'build_conflicts'}) {
        my $missing = check_test_depends($testdata);
        if ($missing) {
            $test_state->skip_test($missing);
            return 1;
        }
    }

    # load skeleton
    if (exists $testdata->{skeleton}) {

        # the skeleton we are working with
        my $skeletonname = $testdata->{skeleton};
        my $skeletonpath = "$TESTSET/skeletons/$suite/$skeletonname";

        my $skeleton = read_config($skeletonpath);

        foreach my $key (keys %{$skeleton}) {
            $testdata->{$key} = $skeleton->{$key};
        }
    }

    if (   $ALWAYS_REBUILD
        or not up_to_date($stampfile, $testdir, $RUNNER_TS)
        or -e "$targetdir/debian/debian") {

        my $skel = $testdata->{skeleton};
        my $tmpldir = "$TESTSET/templates/$suite/";

        $test_state->info_msg(2, "Cleaning up and repopulating $targetdir...");
        runsystem_ok('rm', '-rf', $targetdir);

        # create work directory
        unless (-d $targetdir) {
            $test_state->info_msg(2, "Creating directory $targetdir.");
            make_path($targetdir);
        }

        # populate working directory with specified template sets
        copy_skeleton_template_sets($testdata->{template_sets},
            $targetdir, $TESTSET)
          if exists $testdata->{template_sets};

        # delete templates for which we have originals
        remove_surplus_templates($testdir, $targetdir);

        # copy test specification to working directory
        my $offset = abs2rel($testdir, $TESTSET);
        $test_state->info_msg(2,
            "Copying test specification $offset from $TESTSET to $targetdir.");
        copy_dir_contents($testdir, $targetdir);
    }

    # get builder name
    my $buildername = $testdata->{builder};
    if (length $buildername) {
        my $builderpath = "$targetdir/$buildername";

        # fill builder if needed
        my $buildertemplate = "$builderpath.in";
        fill_template($buildertemplate, $builderpath, $testdata,$RUNNER_TS)
          if -f $buildertemplate;

        if (-f $builderpath) {

            # read builder
            my $builder = read_config($builderpath);
            die 'Could not read builder data.' unless $builder;

            # transfer builder data to test case, but do not override
            foreach my $key (keys %{$builder}) {
                $testdata->{$key} = $builder->{$key}
                  unless exists $testdata->{$key};
            }
        }
    }

    if ($ALWAYS_REBUILD or not up_to_date($stampfile, $testdir, $RUNNER_TS)) {

        # fill remaining templates
        fill_skeleton_templates($testdata->{fill_targets},
            $testdata, $RUNNER_TS, $targetdir, $TESTSET)
          if exists $testdata->{fill_targets};
    }

    return 0;
}

1;

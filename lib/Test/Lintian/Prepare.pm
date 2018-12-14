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
# Prepares the test called $test assumed to be located in $testset/$dir/$test/.
#
sub prepare {
    my ($test_state, $specpath, $runpath, $suite, $outpath,$testset,
        $force_rebuild)
      = @_;

    # read defaults
    my $defaultspath = "$testset/defaults";

    # read default file names
    my $defaultfilespath = "$defaultspath/files";
    die "Cannot find $defaultfilespath" unless -f $defaultfilespath;
    my $files = read_config($defaultfilespath);

    # read test data
    my $descpath = "$specpath/$files->{test_specification}";
    my $testcase = read_config($descpath);

    # read test defaults
    my $descdefaultspath = "$defaultspath/$files->{test_specification}";
    my $defaults = read_config($descdefaultspath);

    foreach my $key (keys %{$defaults}) {
        $testcase->{$key} = $defaults->{$key}
          unless exists $testcase->{$key};
    }

    # record suite
    $testcase->{suite} = $suite;

    my $testname = $testcase->{testname};

    unless ($testcase->{testname} && exists $testcase->{version}) {
        die 'Name or Version missing';
    }

    $testcase->{source} ||= $testcase->{testname};

    $testcase->{date} ||= rfc822date(time);

    if (not $testcase->{prev_version}) {
        $testcase->{prev_version} = '0.0.1';
        $testcase->{prev_version} .= '-1'
          if index($testcase->{version}, '-') > -1;
    }

    $testcase->{host_architecture} = $ENV{'DEB_HOST_ARCH'};
    $testcase->{'standards_version'} ||= $ENV{'POLICY_VERSION'};

    $testcase->{'dh_compat_level'} //= '11';

    $testcase->{'default_build_depends'}
      //= "debhelper (>= $testcase->{dh_compat_level}~)";

    $testcase->{'build_depends'} ||= join(
        ', ',
        grep { $_ }(
            $testcase->{'default_build_depends'},
            $testcase->{'extra_build_depends'}));

    if ($specpath and -d "${specpath}/lintian-include-dir") {
        $testcase->{'lintian_include_dir'} = './lintian-include-dir';
    }

    $testcase->{upstream_version} = $testcase->{version};
    $testcase->{upstream_version} =~ s/-[^-]+$//;
    $testcase->{upstream_version} =~ s/(-|^)(\d+):/$1/;

    my $epochless_version = $testcase->{version};
    $epochless_version =~ s/^\d+://;
    $testcase->{no_epoch} = $epochless_version;

    $test_state->progress('setup');

    die 'Outdated test specification (./debian/debian exists).'
      if -e "$specpath/debian/debian";

    # load skeleton
    if (exists $testcase->{skeleton}) {

        # the skeleton we are working with
        my $skeletonname = $testcase->{skeleton};
        my $skeletonpath = "$testset/skeletons/$suite/$skeletonname";

        my $skeleton = read_config($skeletonpath);

        foreach my $key (keys %{$skeleton}) {
            $testcase->{$key} = $skeleton->{$key};
        }
    }

    if ($force_rebuild
        or -e "$runpath/debian/debian") {

        $test_state->info_msg(2, "Cleaning up and repopulating $runpath...");
        runsystem_ok('rm', '-rf', $runpath);
    }

    # create work directory
    unless (-d $runpath) {
        $test_state->info_msg(2, "Creating directory $runpath.");
        make_path($runpath);
    }

    # populate working directory with specified template sets
    copy_skeleton_template_sets($testcase->{template_sets},$runpath, $testset)
      if exists $testcase->{template_sets};

    # delete templates for which we have originals
    remove_surplus_templates($specpath, $runpath);

    # copy test specification to working directory
    my $offset = abs2rel($specpath, $testset);
    $test_state->info_msg(2,
        "Copying test specification $offset from $testset to $runpath.");
    copy_dir_contents($specpath, $runpath);

    # get builder name
    my $buildername = $testcase->{builder};
    if (length $buildername) {
        my $builderpath = "$runpath/$buildername";

        # fill builder if needed
        my $buildertemplate = "$builderpath.in";
        fill_template($buildertemplate, $builderpath, $testcase,
            $ENV{HARNESS_EPOCH})
          if -f $buildertemplate;

        if (-f $builderpath) {

            # read builder
            my $builder = read_config($builderpath);
            die 'Could not read builder data.' unless $builder;

            # transfer builder data to test case, but do not override
            foreach my $key (keys %{$builder}) {
                $testcase->{$key} = $builder->{$key}
                  unless exists $testcase->{$key};
            }
        }
    }

    # fill remaining templates
    fill_skeleton_templates($testcase->{fill_targets},
        $testcase, $ENV{HARNESS_EPOCH}, $runpath, $testset)
      if exists $testcase->{fill_targets};

    # write the dynamic file names
    my $runfiles = path($runpath)->child('files');
    write_config($files, $runfiles->stringify);

    # write the dynamic test case files
    my $rundesc = path($runpath)->child($files->{test_specification});
    write_config($testcase, $rundesc->stringify);

    return 0;
}

1;

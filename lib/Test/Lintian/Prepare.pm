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
      early_logpath
      logged_prepare
      prepare
    );
}

use Capture::Tiny qw(capture_merged);
use Cwd qw(getcwd);
use File::Copy;
use File::Find::Rule;
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(abs2rel rel2abs splitpath splitdir catpath);
use File::stat;
use List::Util qw(max);
use Path::Tiny;
use Try::Tiny;

use Test::Lintian::ConfigFile qw(read_config write_config);
use Test::Lintian::Helper qw(rfc822date copy_dir_contents);
use Test::Lintian::Templates
  qw(copy_skeleton_template_sets remove_surplus_templates fill_skeleton_templates fill_template);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COMMA => q{,};
use constant NEWLINE => qq{\n};

my $EARLY_LOG_SUFFIX = 'log';

=head1 FUNCTIONS

=over 4

=item early_logpath(RUN_PATH)

Return the path of the early log for the work directory RUN_PATH.

=cut

sub early_logpath {
    my ($runpath)= @_;

    return "$runpath.$EARLY_LOG_SUFFIX";
}

=item logged_prepare(SPEC_PATH, RUN_PATH, TEST_SET, REBUILD)

Prepares the work directory RUN_PATH for the test specified in
SPEC_PATH. The optional parameter REBUILD forces a rebuild if true.

Captures all output and places it in a file near the work directory.
The log can be used as a starting point by the runner after copying
it to a final location.

=cut

sub logged_prepare {
    my ($specpath, $runpath, $testset, $force_rebuild)= @_;

    my $log;
    my $error;

    # capture output
    $log = capture_merged {

        try {
            # prepare
            prepare($specpath, $runpath, $testset, $force_rebuild);
        }
        catch {
            # catch any error
            $error = $_;
        };
    };

    # save log;
    if (defined $runpath) {
        my $logfile = early_logpath($runpath);
        path($logfile)->spew_utf8($log) if $log;
    }

    # print something if there was an error
    if ($error) {
        my $message;
        $message = NEWLINE . $log if length $log;
        $message .= $error;
        die $message;
    }

    return;
}

=item prepare(SPEC_PATH, RUN_PATH, TEST_SET, REBUILD)

Populates a work directory RUN_PATH with data from the test located
in SPEC_PATH. The optional parameter REBUILD forces a rebuild if true.

=cut

sub prepare {
    my ($specpath, $runpath, $testset, $force_rebuild)= @_;

    say '------- Preparation starts here -------';
    say "Work directory is $runpath.";

    # for template fill, earliest date without timewarp warning
    my $data_epoch = max($ENV{HARNESS_EPOCH}//time,$ENV{'POLICY_EPOCH'}//time);

    # read defaults
    my $defaultspath = "$testset/defaults";

    # read default file names
    my $defaultfilespath = "$defaultspath/files";
    die "Cannot find $defaultfilespath" unless -f $defaultfilespath;

    # read file and adjust data age threshold
    my $files = read_config($defaultfilespath);
    $data_epoch= max($data_epoch, stat($defaultfilespath)->mtime);

    # read test data
    my $descpath = "$specpath/$files->{test_specification}";
    my $testcase = read_config($descpath);
    $data_epoch= max($data_epoch, stat($descpath)->mtime);

    # read test defaults
    my $descdefaultspath = "$defaultspath/$files->{test_specification}";
    my $defaults = read_config($descdefaultspath);
    $data_epoch= max($data_epoch, stat($descdefaultspath)->mtime);

    foreach my $key (keys %{$defaults}) {
        $testcase->{$key} = $defaults->{$key}
          unless exists $testcase->{$key};
    }

    # record path to specification
    $testcase->{spec_path} = $specpath;

    unless ($testcase->{testname} && exists $testcase->{version}) {
        die 'Name or Version missing';
    }

    $testcase->{source} ||= $testcase->{testname};

    warn "Cannot override Architecture: in test $testcase->{testname}."
      if length $testcase->{architecture};

    $testcase->{host_architecture} = $ENV{'DEB_HOST_ARCH'}
      //die 'DEB_HOST_ARCH is not set.';

    $testcase->{standards_version} ||= $ENV{'POLICY_VERSION'}
      //die 'Could not get POLICY_VERSION.';

    $testcase->{dh_compat_level} //= $ENV{'DEFAULT_DEBHELPER_COMPAT'}
      //die 'Could not get DEFAULT_DEBHELPER_COMPAT.';

    # add upstream version
    $testcase->{upstream_version} = $testcase->{version};
    $testcase->{upstream_version} =~ s/-[^-]+$//;
    $testcase->{upstream_version} =~ s/(-|^)(\d+):/$1/;

    # version without epoch
    $testcase->{no_epoch} = $testcase->{version};
    $testcase->{no_epoch} =~ s/^\d+://;

    unless ($testcase->{prev_version}) {
        $testcase->{prev_version} = '0.0.1';
        $testcase->{prev_version} .= '-1'
          if index($testcase->{version}, '-') > -1;
    }

    die 'Outdated test specification (./debian/debian exists).'
      if -e "$specpath/debian/debian";

    if (-d $runpath) {

        # check for old build artifacts
        my $buildstamp = "$runpath/build-stamp";
        say 'Found old build artifact.' if -f $buildstamp;

        # check for old debian/debian directory
        my $olddebiandir = "$runpath/debian/debian";
        say 'Found old debian/debian directory.' if -e $olddebiandir;

        # check for rebuild demand
        say 'Forcing rebuild.' if $force_rebuild;

        # delete work directory
        if($force_rebuild || -f $buildstamp || -e $olddebiandir) {
            say "Removing work directory $runpath.";
            remove_tree($runpath);
        }
    }

    # create work directory
    unless (-d $runpath) {
        say "Creating directory $runpath.";
        make_path($runpath);
    }

    # delete old test scripts
    my @oldrunners = File::Find::Rule->file->name('*.t')->in($runpath);
    unlink(@oldrunners);

    # load skeleton
    if (exists $testcase->{skeleton}) {

        # the skeleton we are working with
        my $skeletonname = $testcase->{skeleton};
        my $skeletonpath = "$testset/skeletons/$skeletonname";

        my $skeleton = read_config($skeletonpath);

        foreach my $key (keys %{$skeleton}) {
            $testcase->{$key} = $skeleton->{$key};
        }
    }

    say EMPTY;

    # populate working directory with specified template sets
    copy_skeleton_template_sets($testcase->{template_sets},$runpath, $testset)
      if exists $testcase->{template_sets};

    # delete templates for which we have originals
    remove_surplus_templates($specpath, $runpath);

    say EMPTY;

    # copy test specification to working directory
    my $offset = abs2rel($specpath, $testset);
    say "Copy test specification $offset from $testset to $runpath.";
    copy_dir_contents($specpath, $runpath);

    # get builder name
    my $buildername = $files->{builder};
    if (length $buildername) {
        my $builderpath = "$runpath/$buildername";

        # fill builder if needed
        my $buildertemplate = "$builderpath.in";
        fill_template($buildertemplate, $builderpath, $testcase, $data_epoch)
          if -f $buildertemplate;

        if (-f $builderpath) {

            # read builder
            my $builder = read_config($builderpath);
            die 'Could not read builder data.' unless $builder;

            # adjust age threshold
            $data_epoch= max($data_epoch, stat($builderpath)->mtime);

            # transfer builder data to test case, but do not override
            foreach my $key (keys %{$builder}) {
                $testcase->{$key} = $builder->{$key}
                  unless exists $testcase->{$key};
            }

            # delete builder
            unlink($builderpath);
        }
    }

    # calculate build dependencies
    warn 'Cannot override Build-Depends:'
      if length $testcase->{build_depends};
    combine_fields($testcase, 'build_depends', COMMA . SPACE,
        'default_build_depends', 'extra_build_depends');

    # calculate build conflicts
    warn 'Cannot override Build-Conflicts:'
      if length $testcase->{build_conflicts};
    combine_fields($testcase, 'build_conflicts', COMMA . SPACE,
        'default_build_conflicts', 'extra_build_conflicts');

    # record our effective data age as date, unless given
    $testcase->{date} ||= rfc822date($data_epoch);

    # fill remaining templates
    fill_skeleton_templates($testcase->{fill_targets},
        $testcase, $data_epoch, $runpath, $testset)
      if exists $testcase->{fill_targets};

    # make sure we installed a runner
    my $runnerpath = "$runpath/$testcase->{runner}";
    die "No runner found at $runnerpath"
      unless -f $runnerpath;

    # write the dynamic file names
    my $runfiles = path($runpath)->child('files');
    write_config($files, $runfiles->stringify);

    # set mtime for dynamic file names
    $runfiles->touch($data_epoch);

    # write the dynamic test case file
    my $rundesc = path($runpath)->child($files->{test_specification});
    write_config($testcase, $rundesc->stringify);

    # set mtime for dynamic test data
    $rundesc->touch($data_epoch);

    say EMPTY;

    # announce data age
    say 'Data epoch is : '. rfc822date($data_epoch);

    return;
}

sub combine_fields {
    my ($testcase, $destination, $delimiter, @sources) = @_;

    return unless length $destination;

    # we are combining these contents
    my @contents;
    foreach my $source (@sources) {
        push(@contents, $testcase->{$source}//EMPTY)
          if length $source;
        delete $testcase->{$source};
    }

    # combine
    foreach my $content (@contents) {
        $testcase->{$destination} = join($delimiter,
            grep { $_ }($testcase->{$destination}//EMPTY,$content));
    }

    # delete the combined entry if it is empty
    delete($testcase->{$destination})
      unless length $testcase->{$destination};

    return;
}

=back

=cut

1;

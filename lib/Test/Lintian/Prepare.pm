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
      filleval
    );
}

use Data::Dumper;

use Capture::Tiny qw(capture_merged);
use Cwd qw(getcwd);
use File::Copy;
use File::Find::Rule;
use File::Path qw(make_path remove_tree);
use File::stat;
use List::Util qw(max);
use Path::Tiny;
use Text::Template;
use Try::Tiny;

use Test::Lintian::ConfigFile qw(read_config write_config);
use Test::Lintian::Helper qw(rfc822date copy_dir_contents);
use Test::Lintian::Templates
  qw(copy_skeleton_template_sets remove_surplus_templates fill_skeleton_templates fill_template);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COMMA => q{,};
use constant NEWLINE => qq{\n};

=head1 FUNCTIONS

=over 4

=item prepare(SPEC_PATH, SOURCE_PATH, TEST_SET, REBUILD)

Populates a work directory SOURCE_PATH with data from the test located
in SPEC_PATH. The optional parameter REBUILD forces a rebuild if true.

=cut

sub prepare {
    my ($specpath, $sourcepath, $testset, $force_rebuild)= @_;

    say '------- Preparation starts here -------';
    say "Work directory is $sourcepath.";

    # for template fill, earliest date without timewarp warning
    my $data_epoch = $ENV{'POLICY_EPOCH'}//time;

    # read defaults
    my $defaultspath = "$testset/defaults";

    # read default file names
    my $defaultfilespath = "$defaultspath/files";
    die "Cannot find $defaultfilespath" unless -f $defaultfilespath;

    # read file and adjust data age threshold
    my $files = read_config($defaultfilespath);
    #    $data_epoch= max($data_epoch, stat($defaultfilespath)->mtime);

    # read test data
    my $descpath = "$specpath/$files->{fill_values}";
    my $desc = read_config($descpath);
    #    $data_epoch= max($data_epoch, stat($descpath)->mtime);

    # read test defaults
    my $descdefaultspath = "$defaultspath/$files->{fill_values}";
    my $defaults = read_config($descdefaultspath);
    #    $data_epoch= max($data_epoch, stat($descdefaultspath)->mtime);

    # start with a shallow copy of defaults
    my $testcase = {%$defaults};

    die "Name missing for $specpath"
      unless length $desc->{testname};

    die 'Outdated test specification (./debian/debian exists).'
      if -e "$specpath/debian/debian";

    if (-d $sourcepath) {

        # check for old build artifacts
        my $buildstamp = "$sourcepath/build-stamp";
        say 'Found old build artifact.' if -f $buildstamp;

        # check for old debian/debian directory
        my $olddebiandir = "$sourcepath/debian/debian";
        say 'Found old debian/debian directory.' if -e $olddebiandir;

        # check for rebuild demand
        say 'Forcing rebuild.' if $force_rebuild;

        # delete work directory
        if($force_rebuild || -f $buildstamp || -e $olddebiandir) {
            say "Removing work directory $sourcepath.";
            remove_tree($sourcepath);
        }
    }

    # create work directory
    unless (-d $sourcepath) {
        say "Creating directory $sourcepath.";
        make_path($sourcepath);
    }

    # delete old test scripts
    my @oldrunners = File::Find::Rule->file->name('*.t')->in($sourcepath);
    unlink(@oldrunners);

    my $skeletonname = ($desc->{skeleton} // EMPTY);
    if (length $skeletonname) {

        # load skeleton
        my $skeletonpath = "$testset/skeletons/$skeletonname";
        my $skeleton = read_config($skeletonpath);

        $testcase->{$_} = $skeleton->{$_}for keys %{$skeleton};
    }

    # populate working directory with specified template sets
    copy_skeleton_template_sets($testcase->{template_sets},
        $sourcepath, $testset)
      if exists $testcase->{template_sets};

    # delete templates for which we have originals
    remove_surplus_templates($specpath, $sourcepath);

    # copy test specification to working directory
    my $offset = path($specpath)->relative($testset)->stringify;
    say "Copy test specification $offset from $testset to $sourcepath.";
    copy_dir_contents($specpath, $sourcepath);

    my $valuefolder = ($testcase->{fill_values_folder} // EMPTY);
    if (length $valuefolder) {

        # load all the values in the fill values folder
        my $valuepath = "$sourcepath/$valuefolder";
        my @filepaths
          = File::Find::Rule->file->name('*.values')->in($valuepath);

        for my $filepath (sort @filepaths) {
            my $values = read_config($filepath);

            $testcase->{$_} = $values->{$_}for keys %{$values};
        }
    }

    # add individual settings after skeleton
    $testcase->{$_} = $desc->{$_}for keys %{$desc};

    # record path to specification
    $testcase->{spec_path} = $specpath;

    # record path to specification
    $testcase->{source_path} = $sourcepath;

    # add other helpful info to testcase
    $testcase->{source} ||= $testcase->{testname};

    # record our effective data age as date, unless given
    $testcase->{date} ||= rfc822date($data_epoch);

    warn "Cannot override Architecture: in test $testcase->{testname}."
      if length $testcase->{architecture};

    $testcase->{host_architecture} = $ENV{'DEB_HOST_ARCH'}
      //die 'DEB_HOST_ARCH is not set.';

    $testcase->{standards_version} ||= $ENV{'POLICY_VERSION'}
      //die 'Could not get POLICY_VERSION.';

    $testcase->{dh_compat_level} //= $ENV{'DEFAULT_DEBHELPER_COMPAT'}
      //die 'Could not get DEFAULT_DEBHELPER_COMPAT.';

    # add additional version components
    if (length $testcase->{version}) {

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
              unless ($testcase->{type} // EMPTY) eq 'native';
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

    # fill testcase with itself; do it twice to make sure all is done
    $testcase = fill_hash_from_hash($testcase);
    $testcase = fill_hash_from_hash($testcase);

    say EMPTY;

    # fill remaining templates
    fill_skeleton_templates($testcase->{fill_targets},
        $testcase, $data_epoch, $sourcepath, $testset)
      if exists $testcase->{fill_targets};

    # write the dynamic file names
    my $runfiles = path($sourcepath)->child('files');
    write_config($files, $runfiles->stringify);

    # set mtime for dynamic file names
    $runfiles->touch($data_epoch);

    # write the dynamic test case file
    my $rundesc = path($sourcepath)->child($files->{fill_values});
    write_config($testcase, $rundesc->stringify);

    # set mtime for dynamic test data
    $rundesc->touch($data_epoch);

    say EMPTY;

    # announce data age
    say 'Data epoch is : '. rfc822date($data_epoch);

    return;
}

=item filleval(SPEC_PATH, EVAL_PATH, TEST_SET, REBUILD)

Populates a evaluation directory EVAL_PATH with data from the test located
in SPEC_PATH. The optional parameter REBUILD forces a rebuild if true.

=cut

sub filleval {
    my ($specpath, $evalpath, $testset, $force_rebuild)= @_;

    say '------- Filling evaluation starts here -------';
    say "Evaluation directory is $evalpath.";

    # read defaults
    my $defaultspath = "$testset/defaults";

    # read default file names
    my $defaultfilespath = "$defaultspath/files";
    die "Cannot find $defaultfilespath" unless -f $defaultfilespath;

    # read file with default file names
    my $files = read_config($defaultfilespath);

    # read test data
    my $descpath = "$specpath/$files->{test_specification}";
    my $desc = read_config($descpath);

    # read test defaults
    my $descdefaultspath = "$defaultspath/$files->{test_specification}";
    my $defaults = read_config($descdefaultspath);

    # start with a shallow copy of defaults
    my $testcase = {%$defaults};

    die "Name missing for $specpath"
      unless length $desc->{testname};

    # delete old test scripts
    my @oldrunners = File::Find::Rule->file->name('*.t')->in($evalpath);
    unlink(@oldrunners);

    $testcase->{skeleton} //= $desc->{skeleton};

    my $skeletonname = ($testcase->{skeleton} // EMPTY);
    if (length $skeletonname) {

        # load skeleton
        my $skeletonpath = "$testset/skeletons/$skeletonname";
        my $skeleton = read_config($skeletonpath);

        $testcase->{$_} = $skeleton->{$_}for keys %{$skeleton};
    }

    # add individual settings after skeleton
    $testcase->{$_} = $desc->{$_}for keys %{$desc};

    # populate working directory with specified template sets
    copy_skeleton_template_sets($testcase->{template_sets},$evalpath, $testset)
      if exists $testcase->{template_sets};

    # delete templates for which we have originals
    remove_surplus_templates($specpath, $evalpath);

    # copy test specification to working directory
    my $offset = path($specpath)->relative($testset)->stringify;
    say "Copy test specification $offset from $testset to $evalpath.";
    copy_dir_contents($specpath, $evalpath);

    my $valuefolder = ($testcase->{fill_values_folder} // EMPTY);
    if (length $valuefolder) {

        # load all the values in the fill values folder
        my $valuepath = "$evalpath/$valuefolder";
        my @filepaths
          = File::Find::Rule->file->name('*.values')->in($valuepath);

        for my $filepath (sort @filepaths) {
            my $values = read_config($filepath);

            $testcase->{$_} = $values->{$_}for keys %{$values};
        }
    }

    # add individual settings after skeleton
    $testcase->{$_} = $desc->{$_}for keys %{$desc};

    # fill testcase with itself; do it twice to make sure all is done
    $testcase = fill_hash_from_hash($testcase);
    $testcase = fill_hash_from_hash($testcase);

    say EMPTY;

    # fill remaining templates
    fill_skeleton_templates($testcase->{fill_targets},
        $testcase, time, $evalpath, $testset)
      if exists $testcase->{fill_targets};

    # write the dynamic file names
    my $runfiles = path($evalpath)->child('files');
    write_config($files, $runfiles->stringify);

    # write the dynamic test case file
    my $rundesc = path($evalpath)->child($files->{test_specification});
    write_config($testcase, $rundesc->stringify);

    say EMPTY;

    return;
}

=item combine_fields

=cut

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

=item fill_hash_from_hash

=cut

sub fill_hash_from_hash {
    my ($hashref, $delimiters) = @_;

    my %origin = %{$hashref};
    my %destination;

    $delimiters //= ['[%', '%]'];

    # fill hash with itself
    for my $key (keys %origin) {

        my $template = $origin{$key} // EMPTY;
        my $filler= Text::Template->new(TYPE => 'STRING', SOURCE => $template);
        croak("Cannot read template $template: $Text::Template::ERROR")
          unless $filler;

        my $generated
          = $filler->fill_in(HASH => \%origin, DELIMITERS => $delimiters);
        croak("Could not create string from template $template")
          unless defined $generated;
        $destination{$key} = $generated;
    }

    return \%destination;
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

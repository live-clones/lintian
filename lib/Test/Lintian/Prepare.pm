# Copyright © 2018-2020 Felix Lechner
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

package Test::Lintian::Prepare;

=head1 NAME

Test::Lintian::Prepare -- routines to prepare the work directories

=head1 SYNOPSIS

  use Test::Lintian::Prepare qw(prepare);

=head1 DESCRIPTION

The routines in this module prepare the work directories in which the
tests are run. To do so, they use the specifications in the test set.

=cut

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      prepare
      filleval
    );
}

use Carp;
use Const::Fast;
use Cwd qw(getcwd);
use File::Copy;
use File::Find::Rule;
use File::Path qw(make_path remove_tree);
use File::stat;
use List::Util qw(max);
use Path::Tiny;
use Text::Template;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::Section;

use Test::Lintian::ConfigFile qw(read_config write_config);
use Test::Lintian::Helper qw(rfc822date copy_dir_contents);
use Test::Lintian::Templates
  qw(copy_skeleton_template_sets remove_surplus_templates fill_skeleton_templates);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $COMMA => q{,};

=head1 FUNCTIONS

=over 4

=item prepare(SPEC_PATH, SOURCE_PATH, TEST_SET, REBUILD)

Populates a work directory SOURCE_PATH with data from the test located
in SPEC_PATH. The optional parameter REBUILD forces a rebuild if true.

=cut

sub prepare {
    my ($specpath, $sourcepath, $testset, $force_rebuild)= @_;

    say encode_utf8('------- Preparation starts here -------');
    say encode_utf8("Work directory is $sourcepath.");

    # for template fill, earliest date without timewarp warning
    my $data_epoch = $ENV{'POLICY_EPOCH'}//time;

    # read defaults
    my $defaultspath = "$testset/defaults";

    # read default file names
    my $defaultfilespath = "$defaultspath/files";
    die encode_utf8("Cannot find $defaultfilespath")
      unless -e $defaultfilespath;

    # read file and adjust data age threshold
    my $files = read_config($defaultfilespath);
    #    $data_epoch= max($data_epoch, stat($defaultfilespath)->mtime);

    # read test data
    my $descpath = $specpath . $SLASH . $files->unfolded_value('Fill-Values');
    my $desc = read_config($descpath);
    #    $data_epoch= max($data_epoch, stat($descpath)->mtime);

    # read test defaults
    my $descdefaultspath
      = $defaultspath . $SLASH . $files->unfolded_value('Fill-Values');
    my $defaults = read_config($descdefaultspath);
    #    $data_epoch= max($data_epoch, stat($descdefaultspath)->mtime);

    # start with a shallow copy of defaults
    my $testcase = Lintian::Deb822::Section->new;
    $testcase->store($_, $defaults->value($_)) for $defaults->names;

    die encode_utf8("Name missing for $specpath")
      unless $desc->declares('Testname');

    die encode_utf8('Outdated test specification (./debian/debian exists).')
      if -e "$specpath/debian/debian";

    if (-d $sourcepath) {

        # check for old build artifacts
        my $buildstamp = "$sourcepath/build-stamp";
        say encode_utf8('Found old build artifact.') if -e $buildstamp;

        # check for old debian/debian directory
        my $olddebiandir = "$sourcepath/debian/debian";
        say encode_utf8('Found old debian/debian directory.')
          if -e $olddebiandir;

        # check for rebuild demand
        say encode_utf8('Forcing rebuild.') if $force_rebuild;

        # delete work directory
        if($force_rebuild || -e $buildstamp || -e $olddebiandir) {
            say encode_utf8("Removing work directory $sourcepath.");
            remove_tree($sourcepath);
        }
    }

    # create work directory
    unless (-d $sourcepath) {
        say encode_utf8("Creating directory $sourcepath.");
        make_path($sourcepath);
    }

    # delete old test scripts
    my @oldrunners = File::Find::Rule->file->name('*.t')->in($sourcepath);
    if (@oldrunners) {
        unlink(@oldrunners)
          or die encode_utf8("Cannot unlink @oldrunners");
    }

    my $skeletonname = $desc->unfolded_value('Skeleton');
    if (length $skeletonname) {

        # load skeleton
        my $skeletonpath = "$testset/skeletons/$skeletonname";
        my $skeleton = read_config($skeletonpath);

        $testcase->store($_, $skeleton->value($_)) for $skeleton->names;
    }

    # populate working directory with specified template sets
    copy_skeleton_template_sets($testcase->value('Template-Sets'),
        $sourcepath, $testset)
      if $testcase->declares('Template-Sets');

    # delete templates for which we have originals
    remove_surplus_templates($specpath, $sourcepath);

    # copy test specification to working directory
    my $offset = path($specpath)->relative($testset)->stringify;
    say encode_utf8(
        "Copy test specification $offset from $testset to $sourcepath.");
    copy_dir_contents($specpath, $sourcepath);

    my $valuefolder = $testcase->unfolded_value('Fill-Values-Folder');
    if (length $valuefolder) {

        # load all the values in the fill values folder
        my $valuepath = "$sourcepath/$valuefolder";
        my @filepaths
          = File::Find::Rule->file->name('*.values')->in($valuepath);

        for my $filepath (sort @filepaths) {
            my $fill_values = read_config($filepath);

            $testcase->store($_, $fill_values->value($_))
              for $fill_values->names;
        }
    }

    # add individual settings after skeleton
    $testcase->store($_, $desc->value($_)) for $desc->names;

    # record path to specification
    $testcase->store('Spec-Path', $specpath);

    # record path to specification
    $testcase->store('Source-Path', $sourcepath);

    # add other helpful info to testcase
    $testcase->store('Source', $testcase->unfolded_value('Testname'))
      unless $testcase->declares('Source');

    # record our effective data age as date, unless given
    $testcase->store('Date', rfc822date($data_epoch))
      unless $testcase->declares('Date');

    warn encode_utf8('Cannot override Architecture: in test '
          . $testcase->unfolded_value('Testname'))
      if $testcase->declares('Architecture');

    die encode_utf8('DEB_HOST_ARCH is not set.')
      unless defined $ENV{'DEB_HOST_ARCH'};
    $testcase->store('Host-Architecture', $ENV{'DEB_HOST_ARCH'});

    die encode_utf8('Could not get POLICY_VERSION.')
      unless defined $ENV{'POLICY_VERSION'};
    $testcase->store('Standards-Version', $ENV{'POLICY_VERSION'})
      unless $testcase->declares('Standards-Version');

    die encode_utf8('Could not get DEFAULT_DEBHELPER_COMPAT.')
      unless defined $ENV{'DEFAULT_DEBHELPER_COMPAT'};
    $testcase->store('Dh-Compat-Level', $ENV{'DEFAULT_DEBHELPER_COMPAT'})
      unless $testcase->declares('Dh-Compat-Level');

    # add additional version components
    if ($testcase->declares('Version')) {

        # add upstream version
        my $upstream_version = $testcase->unfolded_value('Version');
        $upstream_version =~ s/-[^-]+$//;
        $upstream_version =~ s/(-|^)(\d+):/$1/;
        $testcase->store('Upstream-Version', $upstream_version);

        # version without epoch
        my $no_epoch = $testcase->unfolded_value('Version');
        $no_epoch =~ s/^\d+://;
        $testcase->store('No-Epoch', $no_epoch);

        unless ($testcase->declares('Prev-Version')) {
            my $prev_version = '0.0.1';
            $prev_version .= '-1'
              unless $testcase->unfolded_value('Type') eq 'native';

            $testcase->store('Prev-Version', $prev_version);
        }
    }

    # calculate build dependencies
    warn encode_utf8('Cannot override Build-Depends:')
      if $testcase->declares('Build-Depends');
    combine_fields($testcase, 'Build-Depends', $COMMA . $SPACE,
        'Default-Build-Depends', 'Extra-Build-Depends');

    # calculate build conflicts
    warn encode_utf8('Cannot override Build-Conflicts:')
      if $testcase->declares('Build-Conflicts');
    combine_fields($testcase, 'Build-Conflicts', $COMMA . $SPACE,
        'Default-Build-Conflicts', 'Extra-Build-Conflicts');

    # fill testcase with itself; do it twice to make sure all is done
    my $hashref = deb822_section_to_hash($testcase);
    $hashref = fill_hash_from_hash($hashref);
    $hashref = fill_hash_from_hash($hashref);
    write_hash_to_deb822_section($hashref, $testcase);

    say encode_utf8($EMPTY);

    # fill remaining templates
    fill_skeleton_templates($testcase->value('Fill-Targets'),
        $hashref, $data_epoch, $sourcepath, $testset)
      if $testcase->declares('Fill-Targets');

    # write the dynamic file names
    my $runfiles = path($sourcepath)->child('files');
    write_config($files, $runfiles->stringify);

    # set mtime for dynamic file names
    $runfiles->touch($data_epoch);

    # write the dynamic test case file
    my $rundesc
      = path($sourcepath)->child($files->unfolded_value('Fill-Values'));
    write_config($testcase, $rundesc->stringify);

    # set mtime for dynamic test data
    $rundesc->touch($data_epoch);

    say encode_utf8($EMPTY);

    # announce data age
    say encode_utf8('Data epoch is : '. rfc822date($data_epoch));

    return;
}

=item filleval(SPEC_PATH, EVAL_PATH, TEST_SET, REBUILD)

Populates a evaluation directory EVAL_PATH with data from the test located
in SPEC_PATH. The optional parameter REBUILD forces a rebuild if true.

=cut

sub filleval {
    my ($specpath, $evalpath, $testset, $force_rebuild)= @_;

    say encode_utf8('------- Filling evaluation starts here -------');
    say encode_utf8("Evaluation directory is $evalpath.");

    # read defaults
    my $defaultspath = "$testset/defaults";

    # read default file names
    my $defaultfilespath = "$defaultspath/files";
    die encode_utf8("Cannot find $defaultfilespath")
      unless -e $defaultfilespath;

    # read file with default file names
    my $files = read_config($defaultfilespath);

    # read test data
    my $descpath
      = $specpath . $SLASH . $files->unfolded_value('Test-Specification');
    my $desc = read_config($descpath);

    # read test defaults
    my $descdefaultspath
      = $defaultspath . $SLASH . $files->unfolded_value('Test-Specification');
    my $defaults = read_config($descdefaultspath);

    # start with a shallow copy of defaults
    my $testcase = Lintian::Deb822::Section->new;
    $testcase->store($_, $defaults->value($_)) for $defaults->names;

    die encode_utf8("Name missing for $specpath")
      unless $desc->declares('Testname');

    # delete old test scripts
    my @oldrunners = File::Find::Rule->file->name('*.t')->in($evalpath);
    if (@oldrunners) {
        unlink(@oldrunners)
          or die encode_utf8("Cannot unlink @oldrunners");
    }

    $testcase->store('Skeleton', $desc->value('Skeleton'))
      unless $testcase->declares('Skeleton');

    my $skeletonname = $testcase->unfolded_value('Skeleton');
    if (length $skeletonname) {

        # load skeleton
        my $skeletonpath = "$testset/skeletons/$skeletonname";
        my $skeleton = read_config($skeletonpath);

        $testcase->store($_, $skeleton->value($_)) for $skeleton->names;
    }

    # add individual settings after skeleton
    $testcase->store($_, $desc->value($_)) for $desc->names;

    # populate working directory with specified template sets
    copy_skeleton_template_sets($testcase->value('Template-Sets'),
        $evalpath, $testset)
      if $testcase->declares('Template-Sets');

    # delete templates for which we have originals
    remove_surplus_templates($specpath, $evalpath);

    # copy test specification to working directory
    my $offset = path($specpath)->relative($testset)->stringify;
    say encode_utf8(
        "Copy test specification $offset from $testset to $evalpath.");
    copy_dir_contents($specpath, $evalpath);

    my $valuefolder = $testcase->unfolded_value('Fill-Values-Folder');
    if (length $valuefolder) {

        # load all the values in the fill values folder
        my $valuepath = "$evalpath/$valuefolder";
        my @filepaths
          = File::Find::Rule->file->name('*.values')->in($valuepath);

        for my $filepath (sort @filepaths) {
            my $fill_values = read_config($filepath);

            $testcase->store($_, $fill_values->value($_))
              for $fill_values->names;
        }
    }

    # add individual settings after skeleton
    $testcase->store($_, $desc->value($_)) for $desc->names;

    # fill testcase with itself; do it twice to make sure all is done
    my $hashref = deb822_section_to_hash($testcase);
    $hashref = fill_hash_from_hash($hashref);
    $hashref = fill_hash_from_hash($hashref);
    write_hash_to_deb822_section($hashref, $testcase);

    say encode_utf8($EMPTY);

    # fill remaining templates
    fill_skeleton_templates($testcase->value('Fill-Targets'),
        $hashref, time, $evalpath, $testset)
      if $testcase->declares('Fill-Targets');

    # write the dynamic file names
    my $runfiles = path($evalpath)->child('files');
    write_config($files, $runfiles->stringify);

    # write the dynamic test case file
    my $rundesc
      = path($evalpath)->child($files->unfolded_value('Test-Specification'));
    write_config($testcase, $rundesc->stringify);

    say encode_utf8($EMPTY);

    return;
}

=item combine_fields

=cut

sub combine_fields {
    my ($testcase, $destination, $delimiter, @sources) = @_;

    return
      unless length $destination;

    # we are combining these contents
    my @contents;
    for my $source (@sources) {
        push(@contents, $testcase->value($source))
          if length $source;
        $testcase->drop($source);
    }

    # combine
    for my $content (@contents) {
        $testcase->store(
            $destination,
            join($delimiter,
                grep { length }($testcase->value($destination),$content)));
    }

    # delete the combined entry if it is empty
    $testcase->drop($destination)
      unless length $testcase->value($destination);

    return;
}

=item deb822_section_to_hash

=cut

sub deb822_section_to_hash {
    my ($section) = @_;

    my %hash;
    for my $name ($section->names) {

        my $transformed = lc $name;
        $transformed =~ s/-/_/g;

        $hash{$transformed} = $section->value($name);
    }

    return \%hash;
}

=item write_hash_to_deb822_section

=cut

sub write_hash_to_deb822_section {
    my ($hashref, $section) = @_;

    for my $name ($section->names) {

        my $transformed = lc $name;
        $transformed =~ s/-/_/g;

        $section->store($name, $hashref->{$transformed});
    }

    return;
}

=item fill_hash_from_hash

=cut

sub fill_hash_from_hash {
    my ($hashref, $delimiters) = @_;

    $delimiters //= ['[%', '%]'];

    my %origin = %{$hashref};
    my %destination;

    # fill hash with itself
    for my $key (keys %origin) {

        my $template = $origin{$key} // $EMPTY;
        my $filler= Text::Template->new(TYPE => 'STRING', SOURCE => $template);
        croak encode_utf8(
            "Cannot read template $template: $Text::Template::ERROR")
          unless $filler;

        my $generated
          = $filler->fill_in(HASH => \%origin, DELIMITERS => $delimiters);
        croak encode_utf8("Could not create string from template $template")
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

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

package Test::Lintian::Build;

=head1 NAME

Test::Lintian::Build -- routines to prepare the work directories

=head1 SYNOPSIS

  use Test::Lintian::Build qw(build_subject);

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
      build_subject
    );
}

use Carp;
use Const::Fast;
use Cwd;
use IPC::Run3;
use List::SomeUtils qw(any);
use Path::Tiny;
use Unicode::UTF8 qw(valid_utf8 encode_utf8);

use Lintian::Util qw(utf8_clean_log);

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Hooks qw(find_missing_prerequisites);

const my $SLASH => q{/};
const my $WAIT_STATUS_SHIFT => 8;

=head1 FUNCTIONS

=over 4

=item build_subject(PATH)

Populates a work directory RUN_PATH with data from the test located
in SPEC_PATH. The optional parameter REBUILD forces a rebuild if true.

=cut

sub build_subject {
    my ($sourcepath, $buildpath) = @_;

    # check test architectures
    die encode_utf8('DEB_HOST_ARCH is not set.')
      unless (length $ENV{'DEB_HOST_ARCH'});

    # read dynamic file names
    my $runfiles = "$sourcepath/files";
    my $files = read_config($runfiles);

    # read dynamic case data
    my $rundescpath
      = $sourcepath . $SLASH . $files->unfolded_value('Fill-Values');
    my $testcase = read_config($rundescpath);

    # skip test if marked
    my $skipfile = "$sourcepath/skip";
    if (-e $skipfile) {
        my $reason = path($skipfile)->slurp_utf8 || 'No reason given';
        say encode_utf8("Skipping test: $reason");
        return;
    }

    # skip if missing prerequisites
    my $missing = find_missing_prerequisites($testcase);
    if (length $missing) {
        say encode_utf8("Missing prerequisites: $missing");
        return;
    }

    path($buildpath)->remove_tree
      if -e $buildpath;

    path($buildpath)->mkpath;

    # get lintian subject
    croak encode_utf8('Could not get subject of Lintian examination.')
      unless $testcase->declares('Build-Product');

    my $build_product = $testcase->unfolded_value('Build-Product');
    my $subject = "$buildpath/$build_product";

    say encode_utf8("Building in $buildpath");

    my $command = $testcase->unfolded_value('Build-Command');
    if (length $command) {

        my $savedir = Cwd::getcwd;
        chdir($buildpath)
          or die encode_utf8("Cannot change to directory $buildpath");

        my $combined_bytes;

        # array command breaks test files/contents/contains-build-path
        run3($command, \undef, \$combined_bytes, \$combined_bytes);
        my $status = ($? >> $WAIT_STATUS_SHIFT);

        chdir($savedir)
          or die encode_utf8("Cannot change to directory $savedir");

        # sanitize log so it is UTF-8 from here on
        my $utf8_bytes = utf8_clean_log($combined_bytes);
        print $utf8_bytes;

        croak encode_utf8("$command failed")
          if $status;
    }

    croak encode_utf8('Build was unsuccessful.')
      unless -e $subject;

    die encode_utf8("Cannot link to build product $build_product")
      if system("cd $buildpath; ln -s $build_product subject");

    return;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

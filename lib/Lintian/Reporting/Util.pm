# Hey emacs! This is a -*- Perl -*- script!
# Lintian::Reporting::Util -- Perl utility functions for lintian's reporting framework

# Copyright © 1998 Christian Schwarz
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
# MA 02110-1301, USA.

package Lintian::Reporting::Util;

=head1 NAME

Lintian::Reporting::Util - Lintian utility functions

=head1 SYNOPSIS

 use Lintian::Reporting::Util qw(load_state_cache find_backlog);

 my $cache = load_state_cache('path/to/state-dir');
 my @backlog = find_backlog('2.12', $cache);

=head1 DESCRIPTION

This module contains a number of utility subs that are nice to have
for the reporting framework, but on their own did not warrant their
own module.

Most subs are imported only on request.

=head1 FUNCTIONS

=over 4

=cut

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Exporter qw(import);
use File::Temp qw(tempfile);
use List::Util qw(shuffle);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);
use YAML::XS ();

use Lintian::Relation::Version qw(versions_equal versions_comparator);

our @EXPORT_OK = (qw(
      load_state_cache
      save_state_cache
      find_backlog
));

const my $WIDELY_READABLE => oct(644);

=item load_state_cache(STATE_DIR)

[Reporting tools only] Load the state cache from STATE_DIR.

=cut

sub load_state_cache {
    my ($state_dir) = @_;
    my $state_file = "$state_dir/state-cache";
    my $state = {};

    return $state
      unless -e $state_file;

    my $yaml = path($state_file)->slurp;

    eval {$state = YAML::XS::Load($yaml);};
    # Not sure what Load does in case of issues; perldoc YAML says
    # very little about it.  Based on YAML::Error, I guess it will
    # write stuff to STDERR and use die/croak, but it remains a
    # guess.
    if (my $err = $@) {
        die encode_utf8(
            "$state_file was invalid; please fix or remove it.\n$err");
    }
    $state //= {};

    if (ref($state) ne 'HASH') {
        die encode_utf8("$state_file was invalid; please fix or remove it.");
    }
    return $state;
}

=item save_state_cache(STATE_DIR, STATE)

[Reporting tools only] Save the STATE cache to STATE_DIR.

=cut

sub save_state_cache {
    my ($state_dir, $state) = @_;
    my $state_file = "$state_dir/state-cache";
    my ($tmp_fd, $tmp_path);

    ($tmp_fd, $tmp_path) = tempfile('state-cache-XXXXXX', DIR => $state_dir);
    ## TODO: Should tmp_fd be binmode'd as we use YAML::XS?

    # atomic replacement of the state file; not a substitute for
    # proper locking, but it will at least ensure that the file
    # is in a consistent state.
    eval {
        print {$tmp_fd} encode_utf8(YAML::XS::Dump($state));

        close($tmp_fd) or die encode_utf8("close $tmp_path: $!");

        # There is no secret in this.  Set it to 0644, so it does not
        # require sudo access on lintian.d.o to read the file.
        chmod($WIDELY_READABLE, $tmp_path);

        rename($tmp_path, $state_file)
          or die encode_utf8("rename $tmp_path -> $state_file: $!");
    };
    if (my $err = $@) {
        if (-e $tmp_path) {
            # Ignore error as we have a more important one
            unlink($tmp_path)
              or warn encode_utf8("Cannot unlink $tmp_path");
        }
        die encode_utf8($err);
    }
    return 1;
}

=item find_backlog(LINTIAN_VERSION, STATE)

[Reporting tools only] Given the current lintian version and the
harness state, return a list of group ids that are part of the
backlog.  The list is sorted based on what version of Lintian
processed the package.

Note the result is by design not deterministic to reduce the
risk of all large packages being in the same run (e.g. like
gcc-5 + gcc-5-cross + gcc-6 + gcc-6-cross).

=cut

sub find_backlog {
    my ($lintian_version, $state) = @_;
    my (@backlog, %by_version, @low_priority);
    for my $group_id (keys(%{$state->{'groups'}})) {
        my $last_version = '0';
        my $group_data = $state->{'groups'}{$group_id};
        my $is_out_of_date;
        # Does this group repeatedly fail with the current version
        # of lintian?
        if (    exists($group_data->{'processing-errors'})
            and $group_data->{'processing-errors'} > 2
            and exists($group_data->{'last-error-by'})
            and $group_data->{'last-error-by'} ne $lintian_version) {
            # To avoid possible "starvation", we will give lower priority
            # to packages that repeatedly fail.  They will be retried as
            # the backlog is cleared.
            push(@low_priority, $group_id);
            next;
        }
        if (exists($group_data->{'out-of-date'})) {
            $is_out_of_date = $group_data->{'out-of-date'};
        }
        if (exists($group_data->{'last-processed-by'})) {
            $last_version = $group_data->{'last-processed-by'};
        }
        $is_out_of_date = 1
          if not versions_equal($last_version, $lintian_version);
        push(@{$by_version{$last_version}}, $group_id) if $is_out_of_date;
    }
    for my $v (sort(versions_comparator keys(%by_version))) {
        push(@backlog, shuffle(@{$by_version{$v}}));
    }
    push(@backlog, shuffle(@low_priority)) if @low_priority;
    return @backlog;
}

=back

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

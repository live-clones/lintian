# -*- perl -*-
# Lintian::Internal::FrontendUtil -- internal helpers for lintian frontends

# Copyright © 2011 Niels Thykier
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Internal::FrontendUtil;

use v5.20;
use warnings;
use utf8;
use autodie;

use Exporter qw(import);

use Carp qw(croak);
use Dpkg::Vendor;

use Lintian::Util qw(check_path safe_qx);

our @EXPORT_OK= qw(check_test_feature default_parallel split_tag
  sanitize_environment open_file_or_fd);

=head1 NAME

Lintian::Internal::FrontendUtil - routines for the front end

=head1 SYNOPSIS

 use Lintian::Internal::FrontendUtil;

=head1 DESCRIPTION

A module with helper routines.

=head1 INSTANCE METHODS

=over 4

=item check_test_feature

=cut

# Check if we are testing a specific feature
#  - e.g. vendor-libdpkg-perl
sub check_test_feature{
    my $env = $ENV{LINTIAN_TEST_FEATURE};
    return 0 unless $env;
    foreach my $feat (@_){
        return 1 if($env =~ m/$feat/);
    }
    return 0;
}

=item sanitize_environment

=cut

{
    # sanitize_environment
    #
    # Reset the environment to a known and well-defined state.
    #
    # We trust nothing but "LINTIAN_*" variables and a select few
    # variables.  This is mostly to ensure we know what state tools
    # (e.g. tar) start in.  In particular, we do not want to inherit
    # some random "TAR_OPTIONS" or "GZIP" values.
    my %PRESERVE_ENV = map { $_ => 1 } qw(
      DEBRELEASE_DEBS_DIR
      HOME
      LANG
      LC_ALL
      LC_MESSAGES
      PATH
      TMPDIR
      XDG_CACHE_HOME
      XDG_CONFIG_DIRS
      XDG_CONFIG_HOME
      XDG_DATA_DIRS
      XDG_DATA_HOME
    );

    sub sanitize_environment {
        for my $key (keys(%ENV)) {
            delete $ENV{$key}
              if not exists($PRESERVE_ENV{$key})
              and $key !~ m/^LINTIAN_/;
        }
        # reset locale definition (necessary for tar)
        $ENV{'LC_ALL'} = 'C';

        # reset timezone definition (also for tar)
        $ENV{'TZ'} = '';

        # When run in some automated ways, Lintian may not have a
        # PATH, but we assume we can call standard utilities without
        # their full path.  If PATH is completely unset, add something
        # basic.
        $ENV{'PATH'} = '/bin:/usr/bin' unless exists($ENV{'PATH'});
        return;
    }
}

=item default_parallel

=cut

# Return the default number of parallelization to be used
sub default_parallel {
    # check cpuinfo for the number of cores...
    my $cpus = safe_qx('nproc');
    if ($cpus =~ m/^\d+$/) {
        # Running up to twice the number of cores usually gets the most out
        # of the CPUs and disks but it might be too aggressive to be the
        # default for -j. Only use <cores>+1 then.
        return $cpus + 1;
    }

    # No decent number of jobs? Just use 2 as a default
    return 2;
}

=item split_tag

=cut

{
    # Matches something like:  (1:2.0-3) [arch1 arch2]
    # - captures the version and the architectures
    my $verarchre = qr,(?: \s* \(( [^)]++ )\) \s* \[ ( [^]]++ ) \]),xo;
    #                             ^^^^^^^^          ^^^^^^^^^^^^
    #                           ( version   )      [architecture ]

    # matches the full deal:
    #    1  222 3333  4444444   5555   666  777
    # -  T: pkg type (version) [arch]: tag [...]
    #           ^^^^^^^^^^^^^^^^^^^^^
    # Where the marked part(s) are optional values.  The numbers above
    # the example are the capture groups.
    my $TAG_REGEX
      = qr/([EWIXOPC]): (\S+)(?: (\S+)(?:$verarchre)?)?: (\S+)(?:\s+(.*))?/;

    sub split_tag {
        my ($tag_input) = @_;
        my $pkg_type;
        return unless $tag_input =~ /^${TAG_REGEX}$/;
        # default value...
        $pkg_type = $3//'binary';
        return ($1, $2, $pkg_type, $4, $5, $6, $7);
    }
}

=item open_file_or_fd

=cut

# open_file_or_fd(TO_OPEN, MODE)
#
# Open a given file or FD based on TO_OPEN and MODE and returns the
# open handle.  Will croak / throw a trappable error on failure.
#
# MODE can be one of "<" (read) or ">" (write).
#
# TO_OPEN is one of:
#  * "-", alias of "&0" or "&1" depending on MODE
#  * "&N", reads/writes to the file descriptor numbered N
#          based on MODE.
#  * "+FILE" (MODE eq '>' only), open FILE in append mode
#  * "FILE", open FILE in read or write depending on MODE.
#            Note that this will truncate the file if MODE
#            is ">".
sub open_file_or_fd {
    my ($to_open, $mode) = @_;
    my $fd;
    # autodie trips this for some reasons (possibly fixed
    # in v2.26)
    no autodie qw(open);
    if ($mode eq '<') {
        if ($to_open eq '-' or $to_open eq '&0') {
            $fd = \*STDIN;
        } elsif ($to_open =~ m/^\&\d+$/) {
            open($fd, '<&=', substr($to_open, 1))
              or die("fdopen $to_open for reading: $!\n");
        } else {
            open($fd, '<', $to_open)
              or die("open $to_open for reading: $!\n");
        }
    } elsif ($mode eq '>') {
        if ($to_open eq '-' or $to_open eq '&1') {
            $fd = \*STDOUT;
        } elsif ($to_open =~ m/^\&\d+$/) {
            open($fd, '>&=', substr($to_open, 1))
              or die("fdopen $to_open for writing: $!\n");
        } else {
            $mode = ">$mode" if $to_open =~ s/^\+//;
            open($fd, $mode, $to_open)
              or die("open $to_open for write/append ($mode): $!\n");
        }
    } else {
        croak("Invalid mode \"$mode\" for open_file_or_fd");
    }
    return $fd;
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

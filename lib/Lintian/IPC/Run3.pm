# Hey emacs! This is a -*- Perl -*- script!
#
# Lintian::IPC::Run3 -- Perl utility functions for lintian
#
# Copyright © 2020 Felix Lechner
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

package Lintian::IPC::Run3;

use v5.20;
use warnings;
use utf8;
use autodie;

use Exporter qw(import);

our @EXPORT_OK;

BEGIN {

    @EXPORT_OK = qw(
      get_deb_info
      safe_qx
    );
}

use Carp qw(croak);
use IPC::Run3;

use Lintian::Deb822::File;

# read up to 40kB at a time.  this happens to be 4096 "tar records"
# (with a block-size of 512 and a block factor of 20, which appear to
# be the defaults).  when we do full reads and writes of READ_SIZE (the
# OS willing), the receiving end will never be with an incomplete
# record.
use constant TAR_RECORD_SIZE => 20 * 512;

use constant EMPTY => q{};
use constant COLON => q{:};
use constant NEWLINE => qq{\n};

=head1 NAME

Lintian::IPC::Run3 - process functions based on IPC::Run3

=head1 SYNOPSIS

 use Lintian::IPC::Run3 qw(safe_qx);

=head1 DESCRIPTION

This module contains process functions based on IPC::Run3.

=head1 FUNCTIONS

=over 4

=item C<safe_qx(@cmd)>

Emulates the C<qx()> operator but with array argument only.

=cut

sub safe_qx {
    my @command = @_;

    my $stdout;
    my $stderr;

    run3(\@command, \undef, \$stdout, \$stderr);

    my $exitcode = $?;
    my $status = ($exitcode >> 8);

    $? = $status;

    return $stdout . $stderr
      if $?;

    return $stdout;
}

=item get_deb_info(DEBFILE)

Extracts the control file from DEBFILE and returns it as a hashref.

DEBFILE must be an ar file containing a "control.tar.gz" member, which
in turn should contain a "control" file.  If the "control" file is
empty this will return an empty list.

Note: the control file is only expected to have a single paragraph and
thus only the first is returned (in the unlikely case that there are
more than one).

=cut

sub get_deb_info {
    my ($path) = @_;

    # get control.tar.gz; dpkg-deb -f $file is slow; use tar instead
    my @dpkg_command = ('dpkg-deb', '--ctrl-tarfile', $path);

    my $dpkg_pid = open(my $from_dpkg, '-|', @dpkg_command)
      or die "Cannot run @dpkg_command: $!";

    # would like to set buffer size to 4096 & TAR_RECORD_SIZE

    # get binary control file
    my $stdout;
    my $stderr;
    my @tar_command = ('tar', '--wildcards', '-xO', '-f', '-', '*control');
    run3(\@tar_command, $from_dpkg, \$stdout, \$stderr);

    my $status = ($? >> 8);
    if ($status) {

        my $message= "Non-zero status $status from @tar_command";
        $message .= COLON . NEWLINE . $stderr
          if length $stderr;

        die $message;
    }

    close $from_dpkg
      or warn "close failed for handle from @dpkg_command: $!";

    waitpid($dpkg_pid, 0);

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->parse_string($stdout);

    return $sections[0];
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

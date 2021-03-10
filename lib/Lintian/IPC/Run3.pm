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

use Exporter qw(import);

our @EXPORT_OK;

BEGIN {

    @EXPORT_OK = qw(
      safe_qx
      xargs
    );
}

use Const::Fast;
use IPC::Run3;

const my $EMPTY => q{};
const my $NULL => qq{\0};

const my $WAIT_STATUS_SHIFT => 8;

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
    my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

    $? = $status;

    return $stdout . $stderr
      if $?;

    return $stdout;
}

=item C<xargs>

=cut

sub xargs {
    my ($command, $arguments, $processor) = @_;

    $command //= [];
    $arguments //= [];

    return
      unless @{$arguments};

    my $input = $EMPTY;
    $input .= $_ . $NULL for @{$arguments};

    my $stdout;
    my $stderr;

    my @combined = (qw(xargs --null --no-run-if-empty), @{$command});

    run3(\@combined, \$input, \$stdout, \$stderr);

    my $exitcode = $?;
    my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

    $processor->($stdout, $stderr, $status, @{$arguments});

    return;
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

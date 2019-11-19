# Copyright © 2019 Felix Lechner
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

package Lintian::Unpack::Task;

use strict;
use warnings;
use v5.16;

use Carp;
use IO::Async::Loop;
use IO::Async::Process;

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Unpack::Task -- Tasks when unpacking collections

=head1 SYNOPSIS

 use Lintian::Unpack::Task;

 my $task = Lintian::Unpack::Task->new;

=head1 DESCRIPTION

A task class for unpacking lab entries.

=head1 CLASS METHODS

=over 4

=back

=head1 INSTANCE METHODS

=over 4

=item run

=cut

sub run {
    my ($self) = @_;

    my $id = $self->id;

    my $script = $self->script;
    my $name = $script->name;

    my $processable = $self->processable;

    my $package = $processable->name;
    my $type = $processable->type;
    my $groupdir = $processable->groupdir;

    # With a non-exec interface, let L::CollScript
    # handle it.  Note that when run under
    # Devel::Cover, we never take this route.
    # This is because Devel::Cover relies on the
    # END handler so all collections would get
    # (more or less) 0 coverage in this case.

    # if ($script->interface ne 'exec'
    #     and not $ENV{'LINTIAN_COVERAGE'}) {

    #     eval {$script->collect($package, $type, $groupdir);};
    #     if ($@) {
    #         print STDERR $@;
    #         return 2;
    #     }

    #     return;
    # }

    # if (my $coverage_arg = $ENV{'LINTIAN_COVERAGE'}) {
    #     my $p5opt = $ENV{'PERL5OPT'} // EMPTY;
    #     $p5opt .= SPACE
    #       unless $p5opt eq EMPTY;
    #     $ENV{'PERL5OPT'} = "${p5opt} ${coverage_arg}";
    # }

    my $loop = IO::Async::Loop->really_new;
    my $future = $loop->new_future;
    my $process = IO::Async::Process->new(

        command => [$script->script_path, $package, $type, $groupdir],

        on_finish => sub {
            my ($pid, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            $future->done("Done unpacking $id: status $status");
        },

        on_exception => sub {
            my ($pid, $exception, $errno, $exitcode) = @_;
            my $message;

            if (length $exception) {
                $message
                  = "Process $id died with exception $exception (errno $errno)";

            } elsif((my $status = W_EXITSTATUS($exitcode)) == 255){
                $message= "Process $id failed to exec() - $errno";
            }else {
                $message= "Process $id exited with exit status $status";
            }
            $future->fail("exec $script->script_path: $message");
        },
    );

    $loop->add($process);

    $loop->await($future);

    croak $future->get
      if $future->is_failed;

    return 0;
}

=item id

=item script

=item processable

=item C<cmap>

=item worklist

=cut

has id => (is => 'rw',);

has script => (is => 'rw',);

has processable => (is => 'rw',);

has cmap => (is => 'rw',);

has worklist => (is => 'rw',);

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

# Copyright © 2019 Felix Lechner <felix.lechner@lease-up.com>
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

use Moo;

use Carp;
use IO::Async::Loop;
use IO::Async::Process;

=head1 NAME

Lintian::Unpack::Task -- Tasks when unpacking collections

=head1 SYNOPSIS

 use Lintian::Unpack::Task;

 my $task = Lintian::Unpack::Task->new;

=head1 DESCRIPTION

A task class for unpacking lab entries.

=head1 CLASS METHODS

=over 4

=item new (COLLMAP, PROFILE[, OPTIONS])

Creates a new unpacker.

COLLMAP is a L<Lintian::DepMap::Properties> describing the dependencies
between the collections.  Each node in COLLMAP must have a
L<Lintian::CollScript> as property.

OPTIONS is an optional hashref containing optional configurations.  If
a key is not present, its value is assumed to be C<undef> unless
otherwise stated.  The following key/values are available:

=over 4

=item "profile"

If this key is present and its value is defined, the value must be
L<Lintian::Profile>.  The unpacker will use the enabled checks of the
Profile to determine what collections to use.

If "profile" is not present or its value is undefined, then all
collections in COLLMAP will be unpacked.

=item "extra-coll"

If this key is present and its value is defined, it must be a
reference to a hash table.  The keys are considered names of "extra"
collections to unpack.  The values in this table is ignored.

Extra collections will be unpacked on top of other collections.

NB: This value is ignored if "profile" is not given.

=item "jobs"

This value is the max number of jobs to be run in parallel.  Can be
changed with the L</jobs> method later.  If omitted, it defaults to
0.  Refer to L</jobs> for more info.

=back

=cut

=back

=head1 INSTANCE METHODS

=over 4

=item prepare_tasks (ERRHANDLER, LAB-ENTRY...)

Prepare a number of L<lab entries|Lintian::Lab::Entry> for unpacking.

The ERRHANDLER should be a code ref, which will be invoked in case
that an entry is not in the laboratory and cannot be created (via
the create method).  It is invoked once per failed entry giving the
entry as first (and only) argument.

If ERRHANDLER returns normally, the entry is skipped (and will not be
unpacked later).  If ERRHANDLER croaks/dies/etc., the method will
attempt to update the status file for any entry it created before
passing back the error to the caller (via die).

LAB-ENTRY is an array of lab entries to be processed.  They must be
instances of L<Lintian::Lab::Entry>, but do not have to exists.  They
will be created as needed.

Returns a truth value if at least one entry needs to be processed
and it did not cause an error.  Otherwise, it returns C<undef>.

NB: The status file is not updated for created entries on successful
return.  It should either be done by running the process_tasks method
or manually.

=cut

sub run {
    my ($self) = @_;

    my $id = $self->id;

    my $script = $self->script;
    my $name = $script->name;

    my $labentry = $self->labentry;

    my $package = $labentry->pkg_name;
    my $type = $labentry->pkg_type;
    my $basedir = $labentry->base_dir;

    # With a non-exec interface, let L::CollScript
    # handle it.  Note that when run under
    # Devel::Cover, we never take this route.
    # This is because Devel::Cover relies on the
    # END handler so all collections would get
    # (more or less) 0 coverage in this case.

    # if ($script->interface ne 'exec'
    #     and not $ENV{'LINTIAN_COVERAGE'}) {

    #     eval {$script->collect($package, $type, $basedir);};
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

        command => [$script->script_path, $package, $type, $basedir],

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

has id => (is => 'rw',);

has script => (is => 'rw',);

has labentry => (is => 'rw',);

has cmap => (is => 'rw',);

has worklist => (is => 'rw',);

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::CollScript(3), Lintian::Lab::Entry(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

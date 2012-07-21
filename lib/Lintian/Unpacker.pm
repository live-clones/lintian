# Copyright (C) 2012 Niels Thykier <niels@thykier.net>
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

package Lintian::Unpacker;

use strict;
use warnings;

use Carp qw(croak);

use base 'Class::Accessor';

use Lintian::Command::Simple;

=head1 NAME

Lintian::Unpacker -- Job handler to unpack collections

=head1 SYNOPSIS

 use Lintian::DepMap::Properties;
 use Lintian::Unpacker;
 
 my $done = 1;
 my $joblimit = 4;
 my $collmap = Lintian::DepMap::Properties->new;
 my %requested = ( 'debfiles' => 1 );
 # Initialise $collmap with the collections and their relations
 # - Each node in $collmap should an instance of L::CollScript
 #   as property.
 my $unpacker = Lintian::Unpacker->new ($collmap, \%requested,
                                        $joblimit);
 
 while (1) {
     my $errhandler = sub {}; # Insert hook
     my @lpkgs = (); # List of Lintian::Lab::Entry instances
     $unpacker->reset_worklist;
     next unless $unpacker->prepare_tasks ($errhandler, @lpkgs);
 
     my %hooks = (
         'coll-hook' => sub {}, # Insert hook
         'finish-hook' => sub {}, # Insert hook
     );
     $unpacker->process_tasks ();
     last if $done;
 }

=head1 DESCRIPTION

An unpacker class to extract data from lab entries and make it
available via L<Lintian::Collect>.

=head1 CLASS METHODS

=over 4

=item new (COLLMAP, REQUESTED[, JOBLIMIT])

Creates a new unpacker.

COLLMAP is a L<Lintian::DepMap::Properties> decribing the dependencies
between the collections.  Each node in COLLMAP must have a
L<Lintian::CollScript> as property.

REQUESTED is a hash table containing requested collections.  The
values are ignored, only the keys are considered.  For existing
entries, as few collections as possible will be processed.  The
collections mentioned in REQUESTED are considered required.

JOBLIMIT is the max number of jobs to be run in parallel.  Can be
changed with the L</jobs> method later.

=cut


sub new {
    my ($class, $collmap, $requested, $jobs) = @_;
    my $ccmap = $collmap->clone;
    $jobs //= 0;
    my $self = {
        'collmap' => $ccmap,
        'jobs' => $jobs,
        'requested' => $requested,
        'running-jobs' => {},
        'worktable' => {},
    };
    # Initialise our copy
    $ccmap->initialise;
    bless $self, $class;
    return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item prepare_tasks (ERRHANDLER, LAB-ENTRY...)

Prepare a number of L<lab entries|Lintian::Lab::Entry> for unpacking.

The ERRHANDLER should be a code ref, which will be invoked in case
that an entry is not in in the laboratory and cannot be created (via
the create method).  It is invoked once per failed entry giving the
entry as first (and only) argument.

If ERRHANDLER returns normally, the entry is skipped (and will not be
unpacked later).  If ERRHANDLER croaks/dies/etc., the method will
attempt to update the status file for any entry it created before
passing back the error to the caller (via die).

LAB-ENTRY is an array of lab entries to be processed.  They must be
instances of L<Lintian::Lab::Entry>, but do not have to exists.  They
will be created as needed.

If at least one entry did not cause an error, it returns a truth
value.  Otherwise, it returns C<undef>.

NB: The status file is not updated for created entries on successful
return.  It should either be done by running the process_tasks method
or manually.

=cut

sub prepare_tasks {
    my ($self, $errorhandler, @lpkgs) = @_;
    my $collmap = $self->{'collmap'};
    my $requested = $self->{'requested'};
    my %worklists = ();
    foreach my $lpkg (@lpkgs) {
        my $changed = 0;
        my $cmap = $collmap->clone;

        if ($lpkg->exists) {
            # It already exists - only collect what we need.
            # - $collmap has everything we need, but in some cases more than that.
            my %need = ();
            my @check;
            my $pkg_type = $lpkg->pkg_type;
            @check = keys %$requested if defined $requested;
            @check = keys $collmap->known unless defined $requested;
            while (my $cname = pop @check) {
                my $coll = $collmap->getp ($cname);
                # Skip collections not relevant to us (they will never
                # be finished and we do not want to use their
                # dependencies if they are the only ones using them)
                next unless $coll->is_type ($pkg_type);
                next if $lpkg->is_coll_finished ($cname, $coll->version);
                $need{$cname} = 1;
                push @check, $coll->needs_info;
            }
            # skip it, unless we need to unpack something.
            next unless %need;
            while (1) {
                my @s = grep { not $need{$_} } $cmap->selectable;
                last if not @s;
                $cmap->satisfy (@s);
            }
        } elsif (not $lpkg->create){
            eval {
                $errorhandler->($lpkg);
            };
            if ($@) {
                # The error handler croaked; attempt to write status
                # files for entries we created.
                my $err = $@;
                foreach my $wlist (values %worklists) {
                    next unless $wlist->{'changed'};
                    my $lpkg = $wlist->{'lab-entry'};
                    # igore errors; there is not much we can do about
                    # it here.
                    $lpkg->update_status_file;
                }
                # ... and pass back the error.
                die $err;
            }
            next;
        } else {
            # created
            $changed = 1;
        }

        $worklists{$lpkg->identifier} = {
            'collmap' => $cmap,
            'lab-entry' => $lpkg,
            'changed' => $changed
        };
    }
    return unless %worklists;
    $self->{'worktable'} = \%worklists;
    return 1;
}

=item process_tasks (HOOKS)

Process the current tasks.  This method blocks until all tasks and
jobs have terminated.

The return value is unspecified.

HOOKS (if given) is a hashref of hooks.  The following hooks are available:

=over 4

=item coll-hook (LPKG, EVENT, COLL, PID[, STATUS])

Called each time a new collection job is started or finished.

LPKG is the L<entry|Lintian::lab::Entry> it is applied to.  COLL is
the L<collection|Lintian::CollScript> being applied.  EVENT is either
"start" for a new job or "finish" for a job terminating.

PID is the process id of the job.  If EVENT is "start" this can be -1
to signal a failure.

STATUS is the exit status of the finishing job.  It is only available
if EVENT is "finish" and if STATUS is non-zero is considered an error.

=item finish-hook (LPKG, STATE[, CHANGED])

Called once or twice for each entry processed at the end of the run.
The LPKG is the L<entry|Lintian::Lab::Entry> being processed.

For the first call, STATE is one of "changed" (the entry has been
modified), "unchanged" (the entry was unmodified) or "failed" (at
least one collection could not be applied).  Note that a "failed"
entry may (or may not) be "changed" depending on where the failure
happened.

In the first call is done before the status file is written and the
hook may alter the entry at this point (e.g. auto-remove unused
collections).  If it does so CHANGED should be invoked as a code-ref
to inform the unpacker of the change.

The second call only happens for entries that has been changed (one
way or another).  STATE will be one of "sf-success" or "sf-error",
which determined on whether or not status file update was successful.
On errors (i.e. "sf-error"), $! will contain the error.

=back

=cut

sub process_tasks {
    my ($self, $hooks) = @_;
    my $worklists = $self->{'worktable'};
    my $running_jobs = $self->{'running-jobs'};
    my $colls = $self->{'collmap'};
    my $jobs = $self->jobs;

    $hooks //= {};
    my $coll_hook = $hooks->{'coll-hook'};
    my $finish_hook = $hooks->{'finish-hook'};
    my %job_data = ();
    my %failed = ();

    while (1) {
        my $newjobs = 0;
        my $nohang = 0;
      PROC:
        foreach my $procid (keys %$worklists){
            # Skip if failed
            next if exists $failed{$procid};
            my $wlist = $worklists->{$procid};
            my $cmap = $wlist->{'collmap'};
            my $lpkg = $wlist->{'lab-entry'};
            my $pkg_name = $lpkg->pkg_name;
            my $pkg_type = $lpkg->pkg_type;
            my $base = $lpkg->base_dir;
            foreach my $coll ($cmap->selectable) {
                my $cs = $colls->getp ($coll);

                # current type?
                unless ($cs->is_type ($pkg_type)) {
                    $cmap->satisfy ($coll);
                    next;
                }

                # check if it has been run previously
                if ($lpkg->is_coll_finished ($coll, $cs->version)) {
                    $cmap->satisfy ($coll);
                    next;
                }
                # Not run before (or out of date)
                $lpkg->_clear_coll_status($coll);

                # collect info
                $cmap->select ($coll);
                $wlist->{'changed'} = 1;
                my $cmd = Lintian::Command::Simple->new;
                my $pid = $cmd->background ($cs->script_path, $pkg_name, $pkg_type, $base);
                $coll_hook->($lpkg, 'start', $cs, $pid) if $coll_hook;
                if ($pid < 0) {
                    # failed - Lets not start any more jobs for this processable
                    $failed{$lpkg->identifier} = 1;
                    last;
                }
                $running_jobs->{$pid} = $cmd;
                $job_data{$pid} = [$cs, $cmap, $lpkg];
                if ($jobs) {
                    # Have we hit the limit of running jobs?
                    last PROC if scalar keys %$running_jobs >= $jobs;
                }
            }
        }
        # wait until a job finishes to run its branches, if any, or skip
        # this package if any of the jobs failed.

        while (my ($pid, $cmd) = Lintian::Command::Simple::wait ($running_jobs, $nohang)) {
            my $jdata = $job_data{$pid};
            my ($cs, $cmap, $lpkg) = @$jdata;
            my $res;
            delete $running_jobs->{$pid};
            delete $job_data{$pid};

            my $status = $cmd->status;

            $coll_hook->($lpkg, 'finish', $cs, $pid, $status)
                if $coll_hook;

            if ($status) {
                # failed ...
                $failed{$lpkg->identifier} = 1;
                next;
            }

            my $coll = $cs->name;
            # The collection was success
            $lpkg->_mark_coll_finished ($coll, $cs->version);
            $cmap->satisfy ($coll);
            # If the entry is marked as failed, don't break the loop
            # for it.
            next if exists $failed{$lpkg->identifier};
            my $new = $cmap->selectable;
            if ($new) {
                $newjobs += $new;
                $nohang = 1;
            }
        }

        # Stop when there are no running jobs and no new pending ones.
        unless (%$running_jobs or $newjobs) {
            # No more running jobs and no new jobs have become available...
            # It is not quite sufficient, so ensure that all jobs have in
            # fact been run.
            my $done = 1;
            foreach my $procid (keys %$worklists) {
                # Failed ones do not count...
                next if $failed{$procid};
                my $cmap = $worklists->{$procid}->{'collmap'};
                if ($cmap->pending) {
                    $done = 0;
                    last;
                }
            }
            last if $done;
        }
    }

    foreach my $procid (keys %$worklists) {
        my $wlist = $worklists->{$procid};
        my $lpkg = $wlist->{'lab-entry'};
        my $changed = $wlist->{'changed'};
        my $state = 'unchanged';
        $state = 'changed' if $changed;
        $state = 'failed' if exists $failed{$procid};
        $finish_hook->($lpkg, $state, sub { $changed = 1 })
            if $finish_hook;
        if ($changed) {
            $state = 'sf-error';
            if ($lpkg->update_status_file) {
                $state = 'sf-success';
            }
            $finish_hook->($lpkg, $state)
                if $finish_hook;
        }
    }
}

=item reset_worklist

Wait for all running jobs (see L</wait_for_jobs>) and discard the
current worklist.

=cut

sub reset_worklist {
    my ($self) = @_;
    $self->wait_for_jobs;
    $self->{'worktable'} = {}
}

=item wait_for_jobs

Block and wait for all running jobs to terminate.  Usually this is not
needed unless process_tasks was interrupted somehow.

=cut

sub wait_for_jobs {
    my ($self) = @_;
    my $running = $self->{'running-jobs'};
    if (%{ $running }) {
        while (my ($key, undef) = Lintian::Command::Simple::wait ($running)) {
            delete $running->{$key};
        }
        $self->{'running-jobs'} = {}
    }
}

=item kill_jobs

Forcefully terminate all running jobs.  Usually this is not needed
unless process_tasks was interrupted somehow.

=cut

sub kill_jobs {
    my ($self) = @_;
    my $running = $self->{'running-jobs'};
    if (%{ $running }) {
        Lintian::Command::Simple::kill ($running);
        $self->{'running-jobs'} = {}
    }
}

=item jobs

Returns or sets the max number of jobs to be processed in parallel.

If the limit is 0, then there is no limit for the number of parallel
jobs.

=cut

Lintian::Unpacker->mk_accessors (qw(jobs));

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::CollScript(3), Lintian::Lab::Entry(3)

=cut

1;


# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

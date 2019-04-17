# Copyright © 2012 Niels Thykier <niels@thykier.net>
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

package Lintian::Unpacker;

use strict;
use warnings;
use v5.16;

use parent 'Class::Accessor::Fast';

use IO::Async::Loop;
use IO::Async::Routine;
use List::Compare;
use List::MoreUtils qw(uniq);
use POSIX;

use Lintian::Output qw(:messages);
use Lintian::Unpack::Task;

use constant EMPTY => q{};
use constant SPACE => q{ };

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
     my @lpkgs; # List of Lintian::Lab::Entry instances
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

sub new {
    my ($class, $collmap, $options) = @_;

    $options //= {};
    my %extra = %{ $options->{'extra-coll'} // {} };
    my $profile = $options->{'profile'};
    my $jobs = $options->{'jobs'} // 0;

    my $clonedmap = $collmap->clone;

    if ($profile) {
        my @requested;
        foreach my $name ($profile->scripts) {
            my $check = $profile->get_script($name);
            push(@requested, $check->needs_info);
        }
        push(@requested, keys %extra);

        # For new entries we take everything in the collmap, which is
        # a bit too much in some cases.  Since we have cloned collmap,
        # we might as well prune the nodes we will not need in our
        # copy.  While not perfect, it reduces the unnecessary work
        # rather well.
        #
        #  Known issue: "lintian -oC files some.dsc" should not need
        #  to do anything because "files" is "binary, udeb"-only.

        # add all ancestors; List::Compare does not need a unique list
        push(@requested, $clonedmap->non_unique_ancestors($_)) for @requested;

        # remove unneeded nodes in our copy
        my @known = $clonedmap->known;
        my $lc = List::Compare->new('--unsorted', \@known, \@requested);
        $clonedmap->unlink($_)for $lc->get_Lonly;

        # clonedmap should remain internally consistent
        die 'Inconsistent collmap after deletion'
          if $clonedmap->missing;
    }

    # Initialise our copy
    $clonedmap->initialise;

    my $self = {
        'cache' => {},
        'coll-priorities' => undef,
        'coll2priority' => {},
        'collmap' => $clonedmap,
        'extra-coll' => \%extra,
        'jobs' => $jobs,
        'profile' => $profile,
        'running-jobs' => {},
        'worktable' => {},
    };

    bless $self, $class;
    return $self;
}

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

sub prepare_tasks {
    my ($self, $errorhandler, @labentries) = @_;

    my %worklists;
    foreach my $labentry (@labentries) {
        my $new;

        eval {$new = $labentry->create;};
        if (my $e = $@) {
            $errorhandler->($labentry, $e);
            next;
        }

        my $type = $labentry->pkg_type;
        my $cmap;

        if (exists $self->{'cache'}{$type}) {
            $cmap = $self->{'cache'}{$type}->clone;
        } else {
            my $collmap = $self->{'collmap'};
            my $cmap2 = Lintian::DepMap::Properties->new;
            my $cond = { 'type' => $type };
            my $coll2priority = $self->{'coll2priority'};

            foreach my $node ($collmap->known) {
                my $script = $collmap->getp($node);
                if (not exists($coll2priority->{$node})) {
                    $coll2priority->{$node} = $script->priority;
                    $self->{'coll-priorities'} = undef;
                }
                $cmap2->add($node, $script->needs_info($cond), $script);
            }

            $cmap2->initialise;

            $self->{'cache'}{$type} = $cmap2;
            $cmap = $cmap2->clone;
        }

        my $needed;
        my %wanted;
        my @requested;
        my $profile = $self->{'profile'};
        if (!$new || $profile) {
            if ($profile) {
                foreach my $name ($profile->scripts) {
                    my $check = $profile->get_script($name);
                    push(@requested, $check->needs_info)
                      if $check->is_check_type($type);
                }
                my $extra = $self->{'extra-coll'};
                push(@requested, keys %$extra)
                  if defined $extra;
                @requested = uniq @requested;
            } else {
                # not new
                @requested = $cmap->known;
            }

            while (my $name = pop @requested) {
                my $script = $cmap->getp($name);
                # Skip collections not relevant to us (they will never
                # be finished and we do not want to use their
                # dependencies if they are the only ones using them)
                next unless $script->is_type($type);
                $wanted{$name} = 1;
                push @requested, $script->needs_info;
            }

            # skip it unless we need to unpack something.
            if (%wanted) {
                $needed = \%wanted;
            } else {
                $cmap = undef;
                $needed = undef;
            }
        } else {
            # if its new and $profile is undef, we have to run all
            # of collections.  So lets exit early.
            $needed = undef;
        }

        next unless $cmap; # nothing to do

        $worklists{$labentry->identifier} = {
            'collmap' => $cmap,
            'lab-entry' => $labentry,
            'needed' => $needed,
        };
    }
    return unless %worklists;
    $self->{'worktable'} = \%worklists;
    if (not $self->{'coll-priorities'}) {
        my $coll2priority = $self->{'coll2priority'};
        my @priorities = sort { $coll2priority->{$a} <=> $coll2priority->{$b} }
          keys(%{$coll2priority});
        $self->{'coll-priorities'} = \@priorities;
    }
    return 1;
}

=item process_tasks (HOOKS)

Process the current tasks.  This method blocks until all tasks and
jobs have terminated.

The return value is unspecified.

HOOKS (if given) is a hashref of hooks.  The following hooks are available:

=over 4

=item coll-hook (LPKG, EVENT, COLL, TASK_ID[, STATUS_OR_ERROR_MSG])

Called each time a new collection job is started or finished.

LPKG is the L<entry|Lintian::Lab::Entry> it is applied to.  COLL is
the L<collection|Lintian::CollScript> being applied.  EVENT is either
"start" for a new job, "start-failed" for a job that failed to
start (appears instead of a "start" event) or "finish" for a job
terminating.

TASK_ID is the task id of the job (a string).

If the event is "finish", then STATUS_OR_ERROR_MSG is the exit code of
the job (non-zero being an error).  If the event is "start-failed", it
is an error message explaining why the job failed to start.  It is not
defined for other events.

=back

=cut

sub process_tasks {
    my ($self, $hooks) = @_;
    my $worklists = $self->{'worktable'};
    my $jobs = $self->jobs;

    my $loop = IO::Async::Loop->new;

    $self->{active} = { map { $_ => 1 } keys %$worklists };
    $self->{failed} = {};

    my @coll_priorities = @{$self->{'coll-priorities'}};
    $self->{colls_not_scheduled} = {};
    $self->{queue} = [];

    for my $name (@coll_priorities) {
        my %procs;
        for my $labid (keys(%{$worklists})) {
            $procs{$labid} = 1;
        }
        $self->{colls_not_scheduled}->{$name} = \%procs;
    }

    my @slices;

    for (0..$jobs-1) {
        my $task = $self->find_next_task();
        last if not $task;

        my $slice = $loop->new_future;
        push(@slices, $slice);

        $self->start_task($slice, $hooks, $task);
    }

    Future->wait_all(@slices)->get;
    return;
}

sub find_next_task {
    my ($self) = @_;

    my $worklists = $self->{'worktable'};
    my @coll_priorities = @{$self->{'coll-priorities'}};
    my $active = $self->{active};
    my $colls = $self->{'collmap'};
    my $colls_not_scheduled = $self->{colls_not_scheduled};
    my $debug_enabled = $Lintian::Output::GLOBAL->debug;

    {
        unless (@{$self->{queue}}) {
            for (my $i = 0; $i < @coll_priorities ; $i++) {
                my $name = $coll_priorities[$i];
                my $script = $colls->getp($name);
                my $procs = $colls_not_scheduled->{$name};
                foreach my $labid (grep { $procs->{$_} } keys %{$active}) {
                    my $wlist = $worklists->{$labid};
                    my $cmap = $wlist->{'collmap'};
                    next if not $cmap->selectable($name);
                    my $labentry = $wlist->{'lab-entry'};
                    my $needed = $wlist->{'needed'};
                    my $type = $labentry->pkg_type;
                    delete($procs->{$labid});
                    # current type?
                    if (not $script->is_type($type)) {
                        $cmap->satisfy($name);
                        next;
                    }

                    # Check if its actually on our TODO list.
                    if (defined $needed and not exists $needed->{$name}) {
                        $cmap->satisfy($name);
                        next;
                    }

                    # collect info
                    $cmap->select($name);
                    debug_msg(3, "READY ${name}-${labid}") if $debug_enabled;

                    my $task = Lintian::Unpack::Task->new;
                    $task->id("${name}-${labid}");
                    $task->script($script);
                    $task->labentry($labentry);
                    $task->cmap($cmap);
                    push(@{$self->{queue}}, $task);

               # If we are dealing with the highest priority type of task, then
               # keep filling the cache (i.e. $i == 0).  Otherwise, stop here
               # to avoid priority inversion due to filling the queue with
               # unimportant tasks.
                    last if $i;
                }
                if (not keys(%{$procs})) {
                    debug_msg(3,
                        "DISCARD $name (all instances have been scheduled)")
                      if $debug_enabled;
                    splice(@coll_priorities, $i, 1);
                    $i--;
                }
                last if @{$self->{queue}};
            }
        }

        if (@{$self->{queue}}) {
            debug_msg(4,
                    'QUEUE non-empty with '
                  . scalar(@{$self->{queue}})
                  . ' item(s).  Taking one.')
              if $debug_enabled;
        }
    }

    return shift @{$self->{queue}}
      if @{$self->{queue}};

    return;
}

sub start_task {
    my ($self, $slice, $hooks, $task) = @_;

    my $id = $task->id;
    my $script = $task->script;
    my $labentry = $task->labentry;
    my $cmap = $task->cmap;

    my $labid = $labentry->identifier;

    my $running_jobs = $self->{'running-jobs'};
    my $active = $self->{active};
    my $failed = $self->{failed};

    my $loop = IO::Async::Loop->new;
    my $debug_enabled = $Lintian::Output::GLOBAL->debug;

    debug_msg(3, "START $id");
    my $pid = -1;

    my $future = $loop->new_future;

    $hooks //= {};
    my $hook = $hooks->{'coll-hook'};

    $hook->($labentry, 'start', $script, $id)
      if $hook;

    eval {

        $pid = $loop->fork(
            code  => sub {

                # fixed upstream in 0.73
                undef($IO::Async::Loop::ONE_TRUE_LOOP);

                my $name = $script->name;
                my $package = $labentry->pkg_name;
                my $type = $labentry->pkg_type;
                my $basedir = $labentry->base_dir;

                # change the process name; possible overwritten by exec
                $0 = "$name (processing $labid)";

                my $ret = 0;
                eval {$script->collect($package, $type, $basedir);};
                if ($@) {
                    print STDERR $@;
                    $ret = 2;
                }
                POSIX::_exit($ret);
            },

            on_exit  => sub {
                my ($pid, $status) = @_;

                delete $running_jobs->{$future};

                debug_msg(3, "FINISH $id ($status)");

                $hook->($labentry, 'finish', $script, $id, $status)
                  if $hook;

                my $name = $script->name;

                if ($status) {
                    # failed ...
                    $failed->{$labid} = 1;
                    delete $active->{$labid};
                }else {
                    # The collection was success
                    $cmap->satisfy($name);
                    # If the entry is marked as failed, don't break the loop
                    # for it.
                    $active->{$labid} = 1
                      unless $failed->{$labid} || !$cmap->selectable;
                }

                $future->done("Script $name for $labid finished");

            });
    };

    $future->on_ready(
        sub {
            my $task = $self->find_next_task();
            $slice->done('No more tasks')
              unless $task;
            $self->start_task($slice, $hooks, $task)
              if $task;

            my $debug_enabled = $Lintian::Output::GLOBAL->debug;
            if ($debug_enabled) {
                my @ids = map { $_->{id} } values %{$self->{'running-jobs'}};
                my $queue = join(', ', sort @ids);
                debug_msg(3, "RUNNING QUEUE: $queue");
            }
        });

    if ($hook) {
        my $err = $@;
        $hook->($labentry, 'failed', $script, $id, $err)
          if $pid == -1;
    }

    $running_jobs->{$future} = { id => $id, pid => $pid };

    return;
}

=item reset_worklist

Wait for all running jobs (see L</wait_for_jobs>) and discard the
current worklist.

=cut

sub reset_worklist {
    my ($self) = @_;
    $self->wait_for_jobs;
    $self->{'worktable'} = {};
    return;
}

=item wait_for_jobs

Block and wait for all running jobs to terminate.  Usually this is not
needed unless process_tasks was interrupted somehow.

=cut

sub wait_for_jobs {
    my ($self) = @_;

    my @futures = keys %{$self->{'running-jobs'}};
    Future->wait_all(@futures)->get;

    $self->{'running-jobs'} = {};
    return;
}

=item kill_jobs

Forcefully terminate all running jobs.  Usually this is not needed
unless process_tasks was interrupted somehow.

=cut

sub kill_jobs {
    my ($self) = @_;

    my @pids = map { $_->{pid} } values %{$self->{'running-jobs'}};
    if (@pids) {
        kill('TERM', @pids);
        kill('KILL', @pids);
    }

    $self->{'running-jobs'} = {};
    return;
}

=item jobs

Returns or sets the max number of jobs to be processed in parallel.

If the limit is 0, then there is no limit for the number of parallel
jobs.

=cut

Lintian::Unpacker->mk_accessors(qw(jobs));

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

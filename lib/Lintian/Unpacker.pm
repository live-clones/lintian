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
use v5.16;

use parent 'Class::Accessor::Fast';

use POSIX;
use IO::Async::Loop;

use Lintian::Output qw(:messages);
use Lintian::Command::Simple qw(wait_any kill_all);
use Lintian::Util qw(do_fork internal_error);

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
    my $ccmap = $collmap->clone;
    my ($req_table, $profile, $extra);
    my $jobs = 0;
    if ($options) {
        $extra = $options->{'extra-coll'} if exists $options->{'extra-coll'};
        $profile = $options->{'profile'} if exists $options->{'profile'};
        $jobs = $options->{'jobs'} if exists $options->{'jobs'};
    }
    my $self = {
        'cache' => {},
        'coll-priorities' => undef,
        'coll2priority' => {},
        'collmap' => $ccmap,
        'jobs' => $jobs,
        'profile' => $profile,
        'running-jobs' => {},
        'worktable' => {},
    };
    if (defined $profile) {
        $req_table = {};
        foreach my $cname ($profile->scripts) {
            my $check = $profile->get_script($cname);
            $req_table->{$_} = 1 for $check->needs_info;
        }
        if ($extra) {
            foreach my $ecoll (keys %$extra) {
                $req_table->{$ecoll} = 1;
            }
        }
    }
    if (defined $req_table) {
        # For new entries we take everything in the collmap, which is
        # a bit too much in some cases.  Since we have cloned collmap,
        # we might as well prune the nodes we will not need in our
        # copy.  While not perfect, it reduces the unnecessary work
        # rather well.
        #
        #  Known issue: "lintian -oC files some.dsc" should not need
        #  to do anything because "files" is "binary, udeb"-only.
        my %needed;
        my @check = keys %$req_table;
        while (my $coll = pop @check) {
            $needed{$coll} = 1;
            push @check,grep { !exists $needed{$_} } $ccmap->parents($coll);
        }
        # remove unneeded nodes in our copy
        foreach my $node ($collmap->known) {
            next if $needed{$node};
            $ccmap->unlink($node);
        }
        # ccmap should not be inconsistent by this change.
        internal_error('Inconsistent collmap after deletion')
          if $ccmap->missing;
    }
    $self->{'extra-coll'} = $extra;

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
    my ($self, $errorhandler, @lpkgs) = @_;
    my %worklists;
    foreach my $lpkg (@lpkgs) {
        my ($cmap, $needed);

        eval {$lpkg->create;};
        if (my $e = $@) {
            $errorhandler->($lpkg, $e);
            next;
        }

        ($cmap, $needed) = $self->_requested_colls($lpkg);

        next unless $cmap; # nothing to do

        $worklists{$lpkg->identifier} = {
            'collmap' => $cmap,
            'lab-entry' => $lpkg,
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

sub _gen_type_coll {
    my ($self, $pkg_type) = @_;
    my $collmap = $self->{'collmap'};
    my $cmap = Lintian::DepMap::Properties->new;
    my $cond = { 'type' => $pkg_type };
    my $coll2priority = $self->{'coll2priority'};

    foreach my $node ($collmap->known) {
        my $coll = $collmap->getp($node);
        if (not exists($coll2priority->{$node})) {
            $coll2priority->{$node} = $coll->priority;
            $self->{'coll-priorities'} = undef;
        }
        $cmap->add($node, $coll->needs_info($cond), $coll);
    }

    $cmap->initialise;

    $self->{'cache'}{$pkg_type} = $cmap;
    return $cmap->clone;
}

sub _requested_colls {
    my ($self, $lpkg, $new) = @_;
    my $profile = $self->{'profile'};
    my $extra = $self->{'extra-coll'};
    my $pkg_type = $lpkg->pkg_type;
    my ($cmap, %needed, @check);

    unless (exists $self->{'cache'}{$pkg_type}) {
        $cmap = $self->_gen_type_coll($pkg_type);
    } else {
        $cmap = $self->{'cache'}{$pkg_type}->clone;
    }

    # if $profile is undef, we have to run all of collections.  So
    # lets exit early.
    return ($cmap, undef) if not $profile;
    if ($profile) {
        my %tmp;
        foreach my $cname ($profile->scripts) {
            my $check = $profile->get_script($cname);
            next unless $check->is_check_type($pkg_type);
            $tmp{$_} = 1 for $check->needs_info;
        }
        @check = keys %tmp;
        push @check, grep { !exists $tmp{$_} } keys %$extra
          if defined $extra;
    } else {
        @check = $cmap->known;
    }
    while (my $cname = pop @check) {
        my $coll = $cmap->getp($cname);
        # Skip collections not relevant to us (they will never
        # be finished and we do not want to use their
        # dependencies if they are the only ones using them)
        next unless $coll->is_type($pkg_type);
        $needed{$cname} = 1;
        push @check, $coll->needs_info;
    }
    # skip it, unless we need to unpack something.
    return ($cmap, \%needed) if %needed;
    return;
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
    my $running_jobs = $self->{'running-jobs'};
    my $colls = $self->{'collmap'};
    my $jobs = $self->jobs;

    my $loop = IO::Async::Loop->new;

    $hooks //= {};
    my $coll_hook = $hooks->{'coll-hook'};
    my %failed;
    my $debug_enabled = $Lintian::Output::GLOBAL->debug;
    my %active = map { $_ => 1 } keys %$worklists;
    my $find_next_task
      = $self->_generate_find_next_tasks_sub(\%active, $worklists, $colls);
    my $schedule_task = sub {
        my ($task_id, $cs, $lpkg, $cmap) = @_;
        my $coll = $cs->name;
        my $procid = $lpkg->identifier;
        my $sch_task_inner = __SUB__;
        debug_msg(3, "START $task_id");
        my $pid = -1;
        eval {
            # We need to use fork - otherwise some of the collections
            # get "stuck" in IPC::Run.  Shucks but such is life.
            $pid = $loop->fork(
                code  => sub {
                    # child
                    my $ret = 0;
                    my $pkg_name = $lpkg->pkg_name;
                    my $pkg_type = $lpkg->pkg_type;
                    my $base = $lpkg->base_dir;
                    if ($cs->interface ne 'exec'
                        and not $ENV{'LINTIAN_COVERAGE'}) {
                        # With a non-exec interface, let L::CollScript
                        # handle it.  Note that when run under
                        # Devel::Cover, we never take this route.
                        # This is because Devel::Cover relies on the
                        # END handler so all collections would get
                        # (more or less) 0 coverage in this case.

                        # For platforms that support it, try to change
                        # our name to the collection being run (like
                        # how it would be with the exec case below).
                        # For platforms that do not support, the child
                        # process will just keep its name as
                        # "lintian".
                        $0 = "${coll} (processing ${procid})";

                        eval {$cs->collect($pkg_name, $pkg_type, $base);};
                        if ($@) {
                            print STDERR $@;
                            $ret = 2;
                        }
                    } else {
                        if (my $coverage_arg = $ENV{'LINTIAN_COVERAGE'}) {
                            my $p5opt = $ENV{'PERL5OPT'} // q{};
                            $p5opt .= ' ' if $p5opt ne q{};
                            $ENV{'PERL5OPT'} = "${p5opt} ${coverage_arg}";
                        }
                        # Its fork + exec - invoke that directly (saves a fork)
                        exec $cs->script_path, $pkg_name, $pkg_type, $base
                          or die "exec $cs->script_path: $!";
                    }
                    POSIX::_exit($ret);
                },
                on_exit      => sub {
                    my ($pid, $status) = @_;
                    delete($running_jobs->{$pid});

                    debug_msg(3, "FINISH $task_id ($status)");

                    $coll_hook->($lpkg, 'finish', $cs, $task_id, $status)
                      if $coll_hook;

                    if ($status) {
                        # failed ...
                        $failed{$procid} = 1;
                        delete $active{$procid};
                    }else {
                        # The collection was success
                        $cmap->satisfy($coll);
                       # If the entry is marked as failed, don't break the loop
                       # for it.
                        $active{$procid} = 1
                          unless $failed{$procid} || !$cmap->selectable;
                    }

                    my @task = $find_next_task->();
                    $sch_task_inner->(@task)
                      if @task;

                    $loop->loop_stop if not %{$running_jobs};
                    if ($debug_enabled) {
                        my $queue = join(', ', sort(values(%{$running_jobs})));
                        debug_msg(3, "RUNNING QUEUE: $queue");
                    }
                });
        };
        if ($coll_hook) {
            my $err = $@;
            $coll_hook->($lpkg, 'start', $cs, $task_id) if $pid > -1;
            $coll_hook->($lpkg, 'start-failed', $cs, $task_id, $err)
              if $pid == -1;
        }
        $running_jobs->{$pid} = $task_id;
        #$loop->add($process);
    };

    for (0..$jobs-1) {
        my @task = $find_next_task->();
        last if not @task;
        $schedule_task->(@task)
          or last;
    }

    $loop->run;
    return;
}

sub _generate_find_next_tasks_sub {
    my ($self, $active_procs, $worklists, $colls) = @_;
    my (@queue);
    my @coll_priorities = @{$self->{'coll-priorities'}};
    my %colls_not_scheduled;
    my $debug_enabled = $Lintian::Output::GLOBAL->debug;
    for my $coll (@coll_priorities) {
        my %procs;
        for my $procid (keys(%{$worklists})) {
            $procs{$procid} = 1;
        }
        $colls_not_scheduled{$coll} = \%procs;
    }

    return sub {
        if (@queue) {
            debug_msg(4,
                    'QUEUE non-empty queue with '
                  . scalar(@queue)
                  . ' item(s).  Taking one.')
              if $debug_enabled;
            return @{shift(@queue)};
        }
        for (my $i = 0; $i < @coll_priorities ; $i++) {
            my $coll = $coll_priorities[$i];
            my $cs = $colls->getp($coll);
            my $procs = $colls_not_scheduled{$coll};
            foreach my $procid (grep { $procs->{$_} } keys(%{$active_procs})) {
                my $wlist = $worklists->{$procid};
                my $cmap = $wlist->{'collmap'};
                next if not $cmap->selectable($coll);
                my $lpkg = $wlist->{'lab-entry'};
                my $needed = $wlist->{'needed'};
                my $pkg_type = $lpkg->pkg_type;
                delete($procs->{$procid});
                # current type?
                if (not $cs->is_type($pkg_type)) {
                    $cmap->satisfy($coll);
                    next;
                }

                # Check if its actually on our TODO list.
                if (defined $needed and not exists $needed->{$coll}) {
                    $cmap->satisfy($coll);
                    next;
                }
                # collect info
                $cmap->select($coll);
                debug_msg(3, "READY ${coll}-${procid}") if $debug_enabled;
                push(@queue, ["${coll}-${procid}", $cs, $lpkg, $cmap]);
               # If we are dealing with the highest priority type of task, then
               # keep filling the cache (i.e. $i == 0).  Otherwise, stop here
               # to avoid priority inversion due to filling the queue with
               # unimportant tasks.
                last if $i;
            }
            if (not keys(%{$procs})) {
                debug_msg(3,
                    "DISCARD $coll (all instances have been scheduled)")
                  if $debug_enabled;
                splice(@coll_priorities, $i, 1);
                $i--;
            }
            last if @queue;
        }

        if (@queue) {
            debug_msg(4,
                    'QUEUE refilled with '
                  . scalar(@queue)
                  . ' item(s).  Taking one.')
              if $debug_enabled;
            return @{shift(@queue)};
        }
        return;
    };
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
    my $running = $self->{'running-jobs'};
    if (%{$running}) {
        while (my ($key, undef) = wait_any($running)) {
            delete $running->{$key};
        }
        $self->{'running-jobs'} = {};
    }
    return;
}

=item kill_jobs

Forcefully terminate all running jobs.  Usually this is not needed
unless process_tasks was interrupted somehow.

=cut

sub kill_jobs {
    my ($self) = @_;
    my $running = $self->{'running-jobs'};
    if (%{$running}) {
        kill_all($running);
        kill_all($running, 'KILL') if %$running;
        $self->{'running-jobs'} = {};
    }
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

# Copyright © 2011 Niels Thykier <niels@thykier.net>
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

package Lintian::Processable::Group;

use strict;
use warnings;
use v5.16;

use Carp;
use File::Spec;
use IO::Async::Loop;
use IO::Async::Routine;
use List::Compare;
use List::MoreUtils qw(uniq);
use Path::Tiny;
use POSIX;
use Time::HiRes qw(gettimeofday tv_interval);

use Lintian::Collect::Group;
use Lintian::Output qw(:messages);
use Lintian::Processable::Binary;
use Lintian::Processable::Buildinfo;
use Lintian::Processable::Changes;
use Lintian::Processable::Source;
use Lintian::Processable::Udeb;
use Lintian::Tags qw(tag);
use Lintian::Unpack::Task;
use Lintian::Util qw(internal_error get_dsc_info strip);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant HYPHEN => q{-};
use constant SLASH => q{/};
use constant UNDERSCORE => q{_};

use Moo;
use namespace::clean;

# A private table of supported types.
my %SUPPORTED_TYPES = (
    'binary'  => 1,
    'buildinfo' => 1,
    'changes' => 1,
    'source'  => 1,
    'udeb'    => 1,
);

=head1 NAME

Lintian::Processable::Group -- A group of objects that Lintian can process

=head1 SYNOPSIS

 use Lintian::Processable::Group;

 my $group = Lintian::Processable::Group->new('lintian_2.5.0_i386.changes');
 foreach my $proc ($group->get_processables){
     printf "%s %s (%s)\n", $proc->pkg_name,
            $proc->pkg_version, $proc->pkg_type;
 }
 # etc.

=head1 DESCRIPTION

Instances of this perl class are sets of
L<processables|Lintian::Processable>.  It allows at most one source
and one changes or buildinfo package per set, but multiple binary packages
(provided that the binary is not already in the set).

=head1 METHODS

=over 4

=item $group->pooldir

Returns or sets the pool directory used by this group.

=item $group->name

Returns a unique identifier for the group based on source and version.

=item $group->binary

Returns a hash reference to the binary processables in this group.

=item $group->buildinfo

Returns the buildinfo processable in this group.

=item $group->changes

Returns the changes processable in this group.

=item $group->source

Returns the source processable in this group.

=item $group->udeb

Returns a hash reference to the udeb processables in this group.

=item jobs

Returns or sets the max number of jobs to be processed in parallel.

If the limit is 0, then there is no limit for the number of parallel
jobs.

=item active

Hash reference for active jobs.

=item failed

Array reference for failed jobs.

=item cache

Cache for some items.

=item coll2priority

Hash linking collection to priority.

=item coll_priorities

Hash with active jobs.

=item group->collmap

Hash with active jobs.

=item colls_not_scheduled

Hash with active jobs.

=item extra_coll

Hash with active jobs.

=item profile

Hash with active jobs.

=item queue

Hash with active jobs.

=item running_jobs

Hash with active jobs.

=item worktable

Hash with active jobs.

=cut

has pooldir => (is => 'rw', default => EMPTY);
has name => (is => 'rw', default => EMPTY);

has binary => (is => 'rw', default => sub{ {} });
has buildinfo => (is => 'rw');
has changes => (is => 'rw');
has source => (is => 'rw');
has udeb => (is => 'rw', default => sub{ {} });

has jobs => (is => 'rw', default => 1);

has coll_priorities => (is => 'rw');

has cache => (is => 'rw', default => sub { {} });
has coll2priority => (is => 'rw', default => sub { {} });
has collmap => (is => 'rw', default => sub { {} });
has profile => (is => 'rw', default => sub { {} });
has running_jobs => (is => 'rw', default => sub { {} });
has worktable => (is => 'rw', default => sub { {} });
has active => (is => 'rw', default => sub { {} });
has failed => (is => 'rw', default => sub { {} });
has colls_not_scheduled => (is => 'rw', default => sub { {} });

has extra_coll => (is => 'rw', default => sub { [] });
has queue => (is => 'rw', default => sub { [] });

=item Lintian::Processable::Group->init_from_file (FILE)

Add all processables from .changes or .buildinfo file FILE.

=cut

sub _get_processable {
    my ($self, $file) = @_;

    my $absolute = path($file)->realpath->stringify;
    croak "Cannot resolve $file: $!"
      unless $absolute;

    my $processable;

    if ($file =~ m/\.dsc$/o) {
        $processable = Lintian::Processable::Source->new;

    } elsif ($file =~ m/\.buildinfo$/o) {
        $processable = Lintian::Processable::Buildinfo->new;

    } elsif ($file =~ m/\.deb$/o) {
        $processable = Lintian::Processable::Binary->new;

    } elsif ($file =~ m/\.udeb$/o) {
        $processable = Lintian::Processable::Udeb->new;

    } elsif ($file =~ m/\.changes$/o) {
        $processable = Lintian::Processable::Changes->new;

    } else {
        croak "$file is not a known type of package";
    }

    $processable->pooldir($self->pooldir);
    $processable->init($absolute);

    return $processable;
}

#  populates $self from a buildinfo or changes file.
sub init_from_file {
    my ($self, $path) = @_;

    return
      unless defined $path;

    my $processable = $self->_get_processable($path);
    $self->add_processable($processable);

    my ($type) = $path =~ m/\.(buildinfo|changes)$/;
    return
      unless defined $type;

    my $info = get_dsc_info($path)
      or internal_error("$path is not a valid $type file");

    my $dir = $path;
    if ($path =~ m,^/+[^/]++$,o){
        # it is "/files.changes?"
        #  - In case you were wondering, we were told not to ask :)
        #   See #624149
        $dir = '/';
    } else {
        # it is "<something>/files.changes"
        $dir =~ s,(.+)/[^/]+$,$1,;
    }
    my $key = $type eq 'buildinfo' ? 'checksums-sha256' : 'files';
    for my $line (split(/\n/o, $info->{$key}//'')) {

        next
          unless defined $line;

        strip($line);

        next
          if $line eq EMPTY;

        # Ignore files that may lead to path traversal issues.

        # We do not need (eg.) md5sum, size, section or priority
        # - just the file name please.
        my $file = (split(/\s+/, $line))[-1];

        # If the field is malformed, $file may be undefined; we also
        # skip it, if it contains a "/" since that is most likely a
        # traversal attempt
        next
          if !$file || $file =~ m,/,;

        unless (-f "$dir/$file") {
            print STDERR "$dir/$file does not exist, exiting\n";
            exit 2;
        }

        # Some file we do not care about (at least not here).
        next
          unless $file =~ /\.u?deb$/
          || $file =~ m/\.dsc$/
          || $file =~ m/\.buildinfo$/;

        my $payload = $self->_get_processable("$dir/$file");
        $self->add_processable($payload);
    }

    return 1;
}

=item unpack

Unpack this group.

=cut

sub unpack {
    my ($self, $collmap, $action, $exit_code_ref)= @_;

    my $clonedmap = $collmap->clone;

    if ($self->profile) {
        my @requested;
        foreach my $check ($self->profile->scripts) {
            my $script = $self->profile->get_script($check);
            push(@requested, $script->needs_info);
        }
        push(@requested, @{$self->extra_coll});

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

    $self->collmap($clonedmap);

    my $all_ok = 1;

    # Kill pending jobs, if any
    $self->kill_jobs;
    $self->wait_for_jobs;

    $self->worktable({});

    # Stop here if there is nothing for us to do
    my @processables = $self->get_processables;
    for my $processable (@processables) {

        $processable->create;

        # for sources pull in all related files so unpacked does not fail
        if ($processable->pkg_type eq 'source') {
            my (undef, $dir, undef)
              = File::Spec->splitpath($processable->pkg_path);
            for my $fs (split(m/\n/o, $processable->info->field('files'))) {
                strip($fs);
                next if $fs eq '';
                my @t = split(/\s+/o,$fs);
                next if ($t[2] =~ m,/,o);
                symlink("$dir/$t[2]", $processable->groupdir . "/$t[2]")
                  or croak("cannot symlink file $t[2]: $!");
            }
        }
    }

    my %worklists;
    foreach my $processable (@processables) {

        my $type = $processable->pkg_type;
        my $cmap;

        if (exists $self->cache->{$type}) {
            $cmap = $self->cache->{$type}->clone;
        } else {
            my $collmap = $self->collmap;
            my $cmap2 = Lintian::DepMap::Properties->new;
            my $cond = { 'type' => $type };
            my $coll2priority = $self->coll2priority;

            foreach my $node ($collmap->known) {
                my $script = $collmap->getp($node);
                if (not exists($coll2priority->{$node})) {
                    $coll2priority->{$node} = $script->priority;
                    $self->coll_priorities(undef);
                }
                $cmap2->add($node, $script->needs_info($cond), $script);
            }

            $cmap2->initialise;

            $self->cache->{$type} = $cmap2;
            $cmap = $cmap2->clone;
        }

        my $needed;
        my %wanted;
        my @requested;
        my $profile = $self->profile;
        if ($profile) {
            if ($profile) {

                foreach my $check ($profile->scripts) {
                    my $script = $profile->get_script($check);
                    push(@requested, $script->needs_info)
                      if $script->is_check_type($type);
                }

                push(@requested, @{$self->extra_coll});
                @requested = uniq @requested;

            } else {
                # not new
                @requested = $cmap->known;
            }

            while (my $check = pop @requested) {
                my $script = $cmap->getp($check);
                # Skip collections not relevant to us (they will never
                # be finished and we do not want to use their
                # dependencies if they are the only ones using them)
                next unless $script->is_type($type);
                $wanted{$check} = 1;
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

        $worklists{$processable->identifier} = {
            'collmap' => $cmap,
            'lab-entry' => $processable,
            'needed' => $needed,
        };
    }

    return 0
      unless %worklists;

    $self->worktable(\%worklists);

    unless($self->coll_priorities) {
        my @priorities
          = sort { $self->coll2priority->{$a} <=> $self->coll2priority->{$b} }
          keys %{$self->coll2priority};

        $self->coll_priorities(\@priorities);
    }

    v_msg('Unpacking packages in group ' . $self->name);

    my %timers;
    my $hook = sub {
        $self->coll_hook($action, $exit_code_ref, \%timers, @_)
          or $all_ok = 0;
    };

    $self->active({ map { $_ => 1 } keys %{$self->worktable} });

    for my $check (@{$self->coll_priorities}) {
        my %procs;
        $procs{$_} = 1 for keys %{$self->worktable};
        $self->colls_not_scheduled->{$check} = \%procs;
    }

    my @slices;

    my $loop = IO::Async::Loop->new;

    for (0..$self->jobs-1) {
        my $task = $self->find_next_task();
        last if not $task;

        my $slice = $loop->new_future;
        push(@slices, $slice);

        $self->start_task($slice, $hook, $task);
    }

    Future->wait_all(@slices)->get;

    return $all_ok;
}

=item coll_hook

Collection hook.

=cut

sub coll_hook {
    my ($self, $action, $exit_code_ref,$timers, $task, $event, $exitval)= @_;

    my $coll = $task->script->name;
    my $procid = $task->processable->identifier;
    my $pkg_name = $task->processable->pkg_name;
    my $pkg_type = $task->processable->pkg_type;

    if ($event eq 'start') {
        $timers->{$task->id} = [gettimeofday];
        debug_msg(1, "Collecting info: $coll for $procid ...");

        return 1;

    } elsif ($event eq 'start-failed' || ($event eq 'finish' && $exitval)) {

        # failed
        my $string
          = "collection $coll failed for $pkg_type package $pkg_name, skipping $action";
        $string .= " error: $exitval"
          if $exitval;
        warning($string);

        my $pkg_type = $task->processable->pkg_type;
        if (   $pkg_type eq 'source'
            or $pkg_type eq 'changes'
            or $pkg_type eq 'buildinfo'){

            $self->$pkg_type(undef);
        } else {
            my $phash = $self->$pkg_type;
            my $id = $task->processable->identifier;

            delete $phash->{$id};
        }

        $$exit_code_ref = 2;

        return 0;

    } elsif ($event eq 'finish') {

        # success
        my $raw_res = tv_interval($timers->{$task->id});
        my $tres = sprintf('%.3fs', $raw_res);
        debug_msg(1, "Collection script $coll for $procid done ($tres)");
        perf_log("$procid,coll/$coll,${raw_res}");

        return 0;
    }

    # unknown event
    return 1;
}

=item process

Process group.

=cut

sub process {
    my ($self, $TAGS, $exit_code_ref, $overrides,$opt, $memory_usage)= @_;

    my $all_ok = 1;

    my $timer = [gettimeofday];

    foreach my $processable ($self->get_processables){
        my $pkg_type = $processable->pkg_type;
        my $procid = $processable->identifier;

        my $file = $processable->pkg_path;

        die "duplicate of file $file added to Lintian::Tags object"
          if exists $TAGS->{info}{$file};

        $TAGS->{info}{$file} = {
            file              => $file,
            package           => $processable->pkg_name,
            version           => $processable->pkg_version,
            arch              => $processable->pkg_arch,
            type              => $processable->pkg_type,
            processable       => $processable,
            overrides         => {},
            'overrides-data'  => {},
        };
        $TAGS->{statistics}{$file} = {
            types     => {},
            severity  => {},
            certainty => {},
            tags      => {},
            overrides => {},
        };

        $TAGS->{current} = $file;

        $Lintian::Output::GLOBAL->print_start_pkg($TAGS->{info}{$file});

        debug_msg(1, 'Base directory for group: ' . $processable->groupdir);

        if (not $opt->{'no-override'}
            and $self->collmap->getp('override-file')) {

            debug_msg(1, 'Loading overrides file (if any) ...');

            my $overrides_file
              = path($processable->info->groupdir)->child('override')
              ->stringify;

            eval {$TAGS->file_overrides($overrides_file);};
            if (my $err = $@) {
                die $err if not ref $err or $err->errno != ENOENT;
            }
        }

        # Filter out the "lintian" check if present - it does no real harm,
        # but it adds a bit of noise in the debug output.
        my @scripts = sort $self->profile->scripts;
        @scripts = grep { $_ ne 'lintian' } @scripts;

        foreach my $script (@scripts) {
            my $cs = $self->profile->get_script($script);
            my $check = $cs->name;
            my $timer = [gettimeofday];

            # The lintian check is done by this frontend and we
            # also skip the check if it is not for this type of
            # package.
            next
              if !$cs->is_check_type($pkg_type);

            my @found;

            debug_msg(1, "Running check: $check on $procid  ...");
            eval {@found = $cs->run_check($processable, $self);};
            my $err = $@;
            my $raw_res = tv_interval($timer);

            for my $tagref (@found) {

                my ($tag, @extra) = @{$tagref};

                # Note, we get the known as it will be suppressed by
                # $self->suppressed below if the tag is not enabled.
                my $info = $self->profile->get_tag($tag, 1);
                croak "tried to issue unknown tag $tag"
                  unless $info;

                next
                  if $TAGS->suppressed($tag);

            # Clean up @extra and collapse it to a string.  Lintian code
            # doesn't treat the distinction between extra arguments to tag() as
            # significant, so we may as well take care of this up front.
                @extra = grep { defined($_) and $_ ne '' }
                  map { s/\n/\\n/g; $_ } @extra;
                my $extra = join(SPACE, @extra) // EMPTY;

                my $override= $TAGS->_check_overrides($tag, $extra);
                $TAGS->_record_stats($tag, $info, $override);

                next
                  if defined $override
                  && !$TAGS->{show_overrides};

                next
                  unless $TAGS->displayed($tag);

                my $file = $TAGS->{info}{$TAGS->{current}};
                $Lintian::Output::GLOBAL->print_tag($file, $info, $extra,
                    $override);
            }

            if ($err) {
                print STDERR $err;
                print STDERR "internal error: cannot run $check check",
                  " on package $procid\n";
                warning("skipping check of $procid");
                $$exit_code_ref = 2;
                $all_ok = 0;

                next;
            }
            my $tres = sprintf('%.3fs', $raw_res);
            debug_msg(1, "Check script $check for $procid done ($tres)");
            perf_log("$procid,check/$check,${raw_res}");
        }

        unless ($$exit_code_ref) {
            my $stats = $TAGS->statistics($processable);
            if ($stats->{types}{E}) {
                $$exit_code_ref = 1;
            }
        }

        # Report override statistics.
        unless ($opt->{'no-override'} || $opt->{'show-overrides'}) {

            my $stats = $TAGS->statistics($processable);

            my $errors = $stats->{overrides}{types}{E} || 0;
            my $warnings = $stats->{overrides}{types}{W} || 0;
            my $info = $stats->{overrides}{types}{I} || 0;

            $overrides->{errors} += $errors;
            $overrides->{warnings} += $warnings;
            $overrides->{info} += $info;
        }

        my $current = $TAGS->{current};
        my $info = $TAGS->{info}{$current};
        my $pkg_overrides = $info->{overrides};

        for my $tag (sort(keys %{$pkg_overrides})) {
            my $overrides;
            next if $TAGS->suppressed($tag);

            $overrides = $pkg_overrides->{$tag};
            for my $extra (sort(keys %{$overrides})) {
                next if $overrides->{$extra};
                $TAGS->{unused_overrides}++;
                $TAGS->tag('unused-override', $tag, $extra);
            }
        }

        $Lintian::Output::GLOBAL->print_end_pkg($info);

        undef $TAGS->{current};
    }

    my $raw_res = tv_interval($timer);
    my $tres = sprintf('%.3fs', $raw_res);
    debug_msg(1, 'Checking all of group ' . $self->name . " done ($tres)");
    perf_log($self->name . ",total-group-check,${raw_res}");

    if ($opt->{'debug'} > 2) {
        my $pivot = ($self->get_processables)[0];
        my $group_id = $pivot->pkg_src . '/' . $pivot->pkg_src_version;
        my $group_usage
          = $memory_usage->([map { $_->info } $self->get_processables]);
        debug_msg(3, "Memory usage [$group_id]: $group_usage");
        for my $processable ($self->get_processables) {
            my $id = $processable->identifier;
            my $usage = $memory_usage->($processable->info);
            my $breakdown = $processable->info->_memory_usage($memory_usage);
            debug_msg(3, "Memory usage [$id]: $usage");
            for my $field (sort(keys(%{$breakdown}))) {
                debug_msg(4, "  -- $field: $breakdown->{$field}");
            }
        }
    }

    return $all_ok;
}

=item clean_lab

Removes the lab files to conserve disk space. Global destruction will
also get these unless we are keeping the lab.

=cut

sub clean_lab {
    my ($self) = @_;

    my $total = [gettimeofday];

    for my $processable ($self->get_processables) {

        my $proc_id = $processable->identifier;
        debug_msg(1, "Auto removing: $proc_id ...");
        my $each = [gettimeofday];

        $processable->remove;

        my $raw_res = tv_interval($each);
        debug_msg(1, "Auto removing: $proc_id done (${raw_res}s)");
        perf_log("$proc_id,auto-remove entry,$raw_res");
    }

    my $raw_res = tv_interval($total);
    my $tres = sprintf('%.3fs', $raw_res);
    debug_msg(1,'Auto-removal all for group ' . $self->name . " done ($tres)");
    perf_log($self->name . ",total-group-auto-remove,$raw_res");

    return;
}

=item $group->add_processable($proc)

Adds $proc to $group.  At most one source and one changes $proc can be
in a $group.  There can be multiple binary $proc's, as long as they
are all unique.  Successive buildinfo $proc's are silently ignored.

This will error out if an additional source or changes $proc is added
to the group. Otherwise it will return a truth value if $proc was
added.

=cut

sub add_processable{
    my ($self, $processable) = @_;

    my $pkg_type = $processable->pkg_type;

    if ($processable->tainted) {
        warn(
            sprintf(
                "warning: tainted %1\$s package '%2\$s', skipping\n",
                $pkg_type, $processable->pkg_name
            ));
        return 0;
    }

    return 0
      if length $self->name
      && $self->name ne $processable->get_group_id;

    $self->name($processable->get_group_id)
      unless length $self->name;

    croak 'Please set pool directory first.'
      unless $self->pooldir;

    croak "Not a supported type ($pkg_type)"
      unless exists $SUPPORTED_TYPES{$pkg_type};

    my $dir = $self->_pool_path($processable);

    $processable->groupdir($dir);

    if ($pkg_type eq 'changes') {
        internal_error("Cannot add another $pkg_type file")
          if $self->changes;
        $self->changes($processable);

    } elsif ($pkg_type eq 'buildinfo') {
        # Ignore multiple .buildinfo files; use the first one
        $self->buildinfo($processable)
          unless $self->buildinfo;

    } elsif ($pkg_type eq 'source'){
        internal_error('Cannot add another source package')
          if $self->source;
        $self->source($processable);

    } else {
        my $phash;
        my $id = $processable->identifier;
        internal_error("Unknown type $pkg_type")
          unless ($pkg_type eq 'binary' or $pkg_type eq 'udeb');
        $phash = $self->$pkg_type;

        # duplicate ?
        return 0
          if exists $phash->{$id};

        $phash->{$id} = $processable;
    }
    $processable->group($self);
    return 1;
}

# Given the package meta data (src_name, type, name, version, arch) return the
# path to it in the Lab.  The path returned will be absolute.
sub _pool_path {
    my ($self, $processable) = @_;

    my $dir = $self->pooldir;
    my $prefix;

    # If it is at least 4 characters and starts with "lib", use "libX"
    # as prefix
    if ($processable->pkg_src =~ m/^lib./) {
        $prefix = substr $processable->pkg_src, 0, 4;
    } else {
        $prefix = substr $processable->pkg_src, 0, 1;
    }

    my $path
      = $prefix
      . SLASH
      . $processable->pkg_src
      . SLASH
      . $processable->pkg_name
      . UNDERSCORE
      . $processable->pkg_version;
    $path .= UNDERSCORE . $processable->pkg_arch
      unless $processable->pkg_type eq 'source';
    $path .= UNDERSCORE . $processable->pkg_type;

    # Turn spaces into dashes - spaces do appear in architectures
    # (i.e. for changes files).
    $path =~ s/\s/-/go;

    # Also replace ":" with "_" as : is usually used for path separator
    $path =~ s/:/_/go;

    return "$dir/pool/$path";
}

=item $group->get_processables([$type])

Returns an array of all processables in $group.  The processables are
returned in the following order: changes (if any), source (if any),
all binaries (if any) and all udebs (if any).

This order is based on the original order that Lintian processed
packages in and some parts of the code relies on this order.

Note if $type is given, then only processables of that type is
returned.

=cut

sub get_processables {
    my ($self, $type) = @_;
    my @result;
    if (defined $type){
        # We only want $type
        if ($type eq 'changes' or $type eq 'source' or $type eq 'buildinfo'){
            return $self->$type;
        }
        return values %{$self->$type}
          if $type eq 'binary'
          or $type eq 'udeb';
        internal_error("Unknown type of processable: $type");
    }
    # We return changes, dsc, buildinfo, debs and udebs in that order,
    # because that is the order lintian used to process a changes
    # file (modulo debs<->udebs ordering).
    #
    # Also correctness of other parts rely on this order.
    foreach my $type (qw(changes source buildinfo)){
        push @result, $self->$type if $self->$type;
    }
    foreach my $type (qw(binary udeb)){
        push @result, values %{$self->$type};
    }
    return @result;
}

=item $group->get_binary_processables

Returns all binary (and udeb) processables in $group.

If $group does not have any binary processables then an empty list is
returned.

=cut

sub get_binary_processables {
    my ($self) = @_;
    my @result;
    foreach my $type (qw(binary udeb)){
        push @result, values %{$self->$type};
    }
    return @result;
}

=item $group->info

Returns L<$info|Lintian::Collect::Group> element for this group.

=cut

sub info {
    my ($self) = @_;
    my $info = $self->{info};
    if (!defined $info) {
        $info = Lintian::Collect::Group->new($self);
        $self->{info} = $info;
    }
    return $info;
}

=item $group->init_shared_cache

Prepare a shared memory cache for all current members of the group.
This is solely a memory saving optimization and is not required for
correct performance.

=cut

sub init_shared_cache {
    my ($self) = @_;
    $self->info; # Side-effect of creating the info object.
    return;
}

=item $group->clear_cache

Discard the info element of all members of this group, so the memory
used by it can be reclaimed.  Mostly useful when checking a lot of
packages (e.g. on lintian.d.o).

=cut

sub clear_cache {
    my ($self) = @_;
    for my $proc ($self->get_processables) {
        $proc->clear_cache;
    }
    delete $self->{info};
    return;
}

=item find_next_task

Find next task.

=cut

sub find_next_task {
    my ($self) = @_;

    my @coll_priorities = @{$self->coll_priorities};

    unless (@{$self->queue}) {

        for (my $i = 0; $i < @coll_priorities ; $i++) {

            my $check = $coll_priorities[$i];
            my $script = $self->collmap->getp($check);
            my $unscheduled = $self->colls_not_scheduled->{$check};

            foreach
              my $procid (grep { $unscheduled->{$_} } keys %{$self->active}) {
                my $wlist = $self->worktable->{$procid};
                my $cmap = $wlist->{'collmap'};

                next
                  unless $cmap->selectable($check);

                my $processable = $wlist->{'lab-entry'};
                my $needed = $wlist->{'needed'};

                delete $unscheduled->{$procid};

                # current type?
                unless ($script->is_type($processable->pkg_type)) {
                    $cmap->satisfy($check);
                    next;
                }

                # Check if its actually on our TODO list.
                if (defined $needed and not exists $needed->{$check}) {
                    $cmap->satisfy($check);
                    next;
                }

                # collect info
                $cmap->select($check);
                debug_msg(3, "READY $check-$procid")
                  if $Lintian::Output::GLOBAL->debug;

                my $task = Lintian::Unpack::Task->new;
                $task->id($check . HYPHEN . $procid);
                $task->script($script);
                $task->processable($processable);
                $task->cmap($cmap);
                push(@{$self->queue}, $task);

               # If we are dealing with the highest priority type of task, then
               # keep filling the cache (i.e. $i == 0).  Otherwise, stop here
               # to avoid priority inversion due to filling the queue with
               # unimportant tasks.
                last if $i;
            }

            unless (keys %{$unscheduled}) {
                debug_msg(3,
                    "DISCARD $check (all instances have been scheduled)")
                  if $Lintian::Output::GLOBAL->debug;
                splice(@coll_priorities, $i, 1);
                $i--;
            }

            last if @{$self->queue};
        }
    }

    if (@{$self->queue}) {
        debug_msg(4,
                'QUEUE non-empty with '
              . scalar(@{$self->queue})
              . ' item(s).  Taking one.')
          if $Lintian::Output::GLOBAL->debug;
    }

    return shift @{$self->queue}
      if @{$self->queue};

    return;
}

=item start_task

Start task.

=cut

sub start_task {
    my ($self, $slice, $hook, $task) = @_;

    my $cmap = $task->cmap;

    my $loop = IO::Async::Loop->new;
    my $debug_enabled = $Lintian::Output::GLOBAL->debug;

    debug_msg(3, 'START ' . $task->id);
    my $pid = -1;

    my $future = $loop->new_future;

    $hook->($task, 'start')
      if $hook;

    eval {

        $pid = $loop->fork(
            code  => sub {

                # fixed upstream in 0.73
                undef($IO::Async::Loop::ONE_TRUE_LOOP);

                my $check = $task->script->name;
                my $procid = $task->processable->identifier;

                my $package = $task->processable->pkg_name;
                my $type = $task->processable->pkg_type;
                my $groupdir = $task->processable->groupdir;

                # change the process name; possible overwritten by exec
                $0 = "$check (processing $procid)";

                my $ret = 0;
                eval {$task->script->collect($package, $type, $groupdir);};
                if ($@) {
                    print STDERR $@;
                    $ret = 2;
                }
                POSIX::_exit($ret);
            },

            on_exit  => sub {
                my ($pid, $status) = @_;

                delete $self->running_jobs->{$future};

                debug_msg(3, 'FINISH ' . $task->id . " ($status)");

                $hook->($task, 'finish', $status)
                  if $hook;

                my $check = $task->script->name;
                my $procid = $task->processable->identifier;

                if ($status) {
                    # failed ...
                    $self->failed->{$procid} = 1;
                    delete $self->active->{$procid};
                }else {
                    # The collection was success
                    $cmap->satisfy($check);
                    # If the entry is marked as failed, don't break the loop
                    # for it.
                    $self->active->{$procid} = 1
                      unless $self->failed->{$procid}
                      || !$cmap->selectable;
                }

                $future->done("Script $check for ". $procid. ' finished');

            });
    };

    $future->on_ready(
        sub {
            my $task = $self->find_next_task();
            $slice->done('No more tasks')
              unless $task;
            $self->start_task($slice, $hook, $task)
              if $task;

            my $debug_enabled = $Lintian::Output::GLOBAL->debug;
            if ($debug_enabled) {
                my @ids = map { $_->{id} } values %{$self->running_jobs};
                my $queue = join(', ', sort @ids);
                debug_msg(3, "RUNNING QUEUE: $queue");
            }
        });

    if ($hook) {
        my $err = $@;
        $hook->($task, 'failed', $err)
          if $pid == -1;
    }

    $self->running_jobs->{$future} = { id => $task->id, pid => $pid };

    return;
}

=item wait_for_jobs

Block and wait for all running jobs to terminate.  Usually this is not
needed unless process_tasks was interrupted somehow.

=cut

sub wait_for_jobs {
    my ($self) = @_;

    my @futures = keys %{$self->running_jobs};
    Future->wait_all(@futures)->get;

    $self->running_jobs({});
    return;
}

=item kill_jobs

Forcefully terminate all running jobs.  Usually this is not needed
unless process_tasks was interrupted somehow.

=cut

sub kill_jobs {
    my ($self) = @_;

    my @pids = map { $_->{pid} } values %{$self->running_jobs};
    if (@pids) {
        kill('TERM', @pids);
        kill('KILL', @pids);
    }

    $self->running_jobs({});
    return;
}

=item DEMOLISH

Moo destructor.

=cut

sub DEMOLISH {
    my ($self, $in_global_destruction) = @_;

    # kill any remaining jobs.
    $self->kill_jobs;

    return;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

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

use Moo;

use Carp;
use File::Spec;
use Path::Tiny;
use Time::HiRes qw(gettimeofday tv_interval);

use Lintian::Collect::Group;
use Lintian::Output qw(:messages);
use Lintian::Processable::Binary;
use Lintian::Processable::Buildinfo;
use Lintian::Processable::Changes;
use Lintian::Processable::Source;
use Lintian::Processable::Udeb;
use Lintian::Util qw(internal_error get_dsc_info strip);

use constant EMPTY => q{};

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

=item $group->lab

Returns or sets the lab used by this pool.

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

=cut

has lab => (is => 'rw');
has name => (is => 'rw', default => EMPTY);

has binary => (is => 'rw', default => sub{ {} });
has buildinfo => (is => 'rw');
has changes => (is => 'rw');
has source => (is => 'rw');
has udeb => (is => 'rw', default => sub{ {} });

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

    $processable->lab($self->lab);
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
          if $line eq '';

        # Ignore files that may lead to path traversal issues.

        # We do not need (eg.) md5sum, size, section or priority
        # - just the file name please.
        my $file = (split(/\s+/o, $line))[-1];

        # If the field is malformed, $file may be undefined; we also
        # skip it, if it contains a "/" since that is most likely a
        # traversal attempt
        next
          if !$file || $file =~ m,/,o;

        unless (-f "$dir/$file") {
            print STDERR "$dir/$file does not exist, exiting\n";
            exit 2;
        }

        if (    $file !~ /\.u?deb$/o
            and $file !~ m/\.dsc$/o
            and $file !~ m/\.buildinfo$/o) {

            # Some file we do not care about (at least not here).
            next;
        }

        my $payload = $self->_get_processable("$dir/$file");
        $self->add_processable($payload);
    }

    return 1;
}

=item unpack

Unpack this group.

=cut

sub unpack {
    my ($self, $unpacker, $action, $exit_code_ref)= @_;

    my $all_ok = 1;

    # Kill pending jobs, if any
    $unpacker->kill_jobs;
    $unpacker->reset_worklist;

    # Stop here if there is nothing list for us to do
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
                symlink("$dir/$t[2]", $processable->base_dir . "/$t[2]")
                  or croak("cannot symlink file $t[2]: $!");
            }
        }
    }

    return 0
      unless $unpacker->prepare_tasks(@processables);

    v_msg('Unpacking packages in group ' . $self->name);

    my %timers;
    my $hook = sub {
        $self->coll_hook($action, $exit_code_ref, \%timers, @_)
          or $all_ok = 0;
    };

    $unpacker->process_tasks($hook);

    return $all_ok;
}

=item coll_hook

Collection hook.

=cut

sub coll_hook {
    my ($self, $action, $exit_code_ref,$timers, $task, $event, $exitval)= @_;

    my $coll = $task->script->name;
    my $procid = $task->labentry->identifier;
    my $pkg_name = $task->labentry->pkg_name;
    my $pkg_type = $task->labentry->pkg_type;

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

        $self->remove_processable($task->labentry);
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

=item post_pkg_process_overrides

Process overrides.

=cut

sub post_pkg_process_overrides{
    my ($lpkg, $TAGS, $overrides, $opt) = @_;

    # Report override statistics.
    unless ($opt->{'no-override'} || $opt->{'show-overrides'}) {

        my $stats = $TAGS->statistics($lpkg);

        my $errors = $stats->{overrides}{types}{E} || 0;
        my $warnings = $stats->{overrides}{types}{W} || 0;
        my $info = $stats->{overrides}{types}{I} || 0;

        $overrides->{errors} += $errors;
        $overrides->{warnings} += $warnings;
        $overrides->{info} += $info;
    }

    return;
}

=item process

Process group.

=cut

sub process {
    my ($self, $PROFILE, $TAGS,$collmap, $exit_code_ref, $overrides,
        $opt, $memory_usage)
      = @_;

    my $all_ok = 1;

    my $timer = [gettimeofday];

  PROC:
    foreach my $lpkg ($self->get_processables){
        my $pkg_type = $lpkg->pkg_type;
        my $procid = $lpkg->identifier;

        $TAGS->file_start($lpkg);

        debug_msg(1, 'Base directory in lab: ' . $lpkg->base_dir);

        if (not $opt->{'no-override'} and $collmap->getp('override-file')) {
            debug_msg(1, 'Loading overrides file (if any) ...');
            $TAGS->load_overrides;
        }

        # Filter out the "lintian" check if present - it does no real harm,
        # but it adds a bit of noise in the debug output.
        my @scripts = sort $PROFILE->scripts;
        @scripts = grep { $_ ne 'lintian' } @scripts;

        foreach my $script (@scripts) {
            my $cs = $PROFILE->get_script($script);
            my $check = $cs->name;
            my $timer = [gettimeofday];

            # The lintian check is done by this frontend and we
            # also skip the check if it is not for this type of
            # package.
            next
              if !$cs->is_check_type($pkg_type);

            debug_msg(1, "Running check: $check on $procid  ...");
            eval {$cs->run_check($lpkg, $self);};
            my $err = $@;
            my $raw_res = tv_interval($timer);

            if ($err) {
                print STDERR $err;
                print STDERR "internal error: cannot run $check check",
                  " on package $procid\n";
                warning("skipping check of $procid");
                $$exit_code_ref = 2;
                $all_ok = 0;
                next PROC;
            }
            my $tres = sprintf('%.3fs', $raw_res);
            debug_msg(1, "Check script $check for $procid done ($tres)");
            perf_log("$procid,check/$check,${raw_res}");
        }

        unless ($$exit_code_ref) {
            my $stats = $TAGS->statistics($lpkg);
            if ($stats->{types}{E}) {
                $$exit_code_ref = 1;
            }
        }
        post_pkg_process_overrides($lpkg, $TAGS, $overrides);
    } # end foreach my $lpkg ($self->get_processable)

    $TAGS->file_end;

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
        for my $lpkg ($self->get_processables) {
            my $id = $lpkg->identifier;
            my $usage = $memory_usage->($lpkg->info);
            my $breakdown = $lpkg->info->_memory_usage($memory_usage);
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
        debug_msg(1, "Auto removing: ${proc_id} ...");
        my $each = [gettimeofday];

        $processable->remove;

        my $raw_res = tv_interval($each);
        debug_msg(1, "Auto removing: ${proc_id} done (${raw_res}s)");
        perf_log("$proc_id,auto-remove entry,${raw_res}");
    }

    my $raw_res = tv_interval($total);
    my $tres = sprintf('%.3fs', $raw_res);
    debug_msg(1,'Auto-removal all for group ' . $self->name . " done ($tres)");
    perf_log($self->name . ",total-group-auto-remove,${raw_res}");

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

    croak 'Please set lab first.'
      unless $self->lab;

    croak "Not a supported type ($pkg_type)"
      unless exists $SUPPORTED_TYPES{$pkg_type};

    my $dir = $self->_pool_path(
        $processable->pkg_src,$processable->pkg_type,
        $processable->pkg_name,$processable->pkg_version,
        $processable->pkg_arch
    );

    $processable->base_dir($dir);

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
    my ($self, $pkg_src, $pkg_type, $pkg_name, $pkg_version, $pkg_arch) = @_;

    my $dir = $self->lab->basedir;
    my $p;

    # If it is at least 4 characters and starts with "lib", use "libX"
    # as prefix
    if ($pkg_src =~ m/^lib./o) {
        $p = substr $pkg_src, 0, 4;
    } else {
        $p = substr $pkg_src, 0, 1;
    }

    $p  = "$p/$pkg_src/${pkg_name}_${pkg_version}";
    $p .= "_${pkg_arch}" unless $pkg_type eq 'source';
    $p .= "_${pkg_type}";

    # Turn spaces into dashes - spaces do appear in architectures
    # (i.e. for changes files).
    $p =~ s/\s/-/go;

    # Also replace ":" with "_" as : is usually used for path separator
    $p =~ s/:/_/go;

    return "$dir/pool/$p";
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

=item $group->remove_processable($proc)

Removes $proc from $group

=cut

sub remove_processable {
    my ($self, $proc) = @_;
    my $pkg_type = $proc->pkg_type;
    if (   $pkg_type eq 'source'
        or $pkg_type eq 'changes'
        or $pkg_type eq 'buildinfo'){

        $self->$pkg_type(undef);

    } else {
        my $phash = $self->$pkg_type;
        my $id = $proc->identifier;

        delete $phash->{$id};
    }
    return 1;
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

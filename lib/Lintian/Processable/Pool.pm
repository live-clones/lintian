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

## Represents a pool of processables (Lintian::Processable)
package Lintian::Processable::Pool;

use strict;
use warnings;

use Carp qw(croak);
use Cwd();
use File::Temp qw(tempdir);
use Time::HiRes qw(gettimeofday tv_interval);
use Path::Tiny;
use POSIX qw(:sys_wait_h);

use Lintian::DepMap;
use Lintian::DepMap::Properties;
use Lintian::Processable::Group;
use Lintian::Util;

use constant EMPTY => q{};
use constant SPACE => q{ };

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Processable::Pool -- Pool of processables

=head1 SYNOPSIS

 use Lintian::Processable::Pool;
 
 my $pool = Lintian::Processable::Pool->new;
 $pool->add_file('foo.changes');
 $pool->add_file('bar.dsc');
 $pool->add_file('baz.deb');
 $pool->add_file('qux.buildinfo');
 foreach my $gname ($pool->get_group_names){
    my $group = $pool->get_group($gname);
    process($gname, $group);
 }

=head1 METHODS

=over 4

=item $pool->groups

Returns a hash reference to the list of processable groups that are currently
in the pool. The key is a unique identifier based on name and version.

=cut

has groups => (is => 'rwp', default => sub{ {} });

# must be absolute; frontend/lintian depends on it
has basedir => (
    is => 'rwp',
    default => sub {

        my $relative = tempdir('temp-lintian-lab-XXXXXXXXXX', 'TMPDIR' => 1);

        my $absolute = Cwd::abs_path($relative);
        croak "Could not resolve $relative: $!"
          unless $absolute;

        path("$absolute/pool")->mkpath({mode => 0777});

        return $absolute;
    });
has keep => (is => 'rw', default => 0);

=item $pool->basedir

Returns the base directory for the pool. Most likely it's a temporary directory.

=item $pool->keep

Returns or accepts a boolean value that indicates whether the lab should be
removed when Lintian finishes. Used for debugging.

=item $pool->add_group($group)

Adds a group to the pool.

=cut

sub add_group {
    my ($self, $group) = @_;

    my $name = $group->name;

    unless (exists $self->groups->{$name}){

        # group does not exist; just add whole
        $self->groups->{$name} = $group;

        return 1;
    }

    # group exists; merge & accept all new
    my $added = 0;

    my $old = $self->groups->{$name};

    for my $type (qw/source buildinfo changes/) {

        if (!defined $old->$type && defined $group->$type) {
            $old->add_processable($group->$type);
            $added = 1;
        }
    }

    foreach my $bin ($group->get_binary_processables){
        # New binary package ?
        my $was_new = $old->add_processable($bin);
        $added ||= $was_new;
    }

    return $added;
}

=item $pool->process

Process the pool.

=cut

sub process{
    my (
        $self, $action,$PROFILE,$TAGS,
        $exit_code_ref, $opt,$memory_usage,$STATUS_FD,
        $unpack_info_ref, $OUTPUT
    ) = @_;

    # $map is just here to check that all the needed collections are present.
    my $map = Lintian::DepMap->new;
    my $collmap = Lintian::DepMap::Properties->new;

    my $dirname = "$ENV{INIT_ROOT}/collection";
    opendir(my $dir, $dirname)
      or die "Cannot open directory $dirname";

    foreach my $file (readdir $dir) {
        next
          if $file =~ m/^\./;
        next
          unless $file =~ m/\.desc$/;

        my $cs = Lintian::CollScript->new("$dirname/$file");

        $OUTPUT->debug_msg(2,
            'Read collector description for ' . $cs->name . '...');
        $collmap->add($cs->name, $cs->needs_info, $cs);
        $map->addp('coll-' . $cs->name, 'coll-', $cs->needs_info);
    }

    closedir($dir)
      or warn 'Close failed';

    my @scripts = sort $PROFILE->scripts;
    $OUTPUT->debug_msg(
        1,
        "Selected action: $action",
        sprintf('Selected checks: %s', join(',', @scripts)),
        "Parallelization limit: $opt->{'jobs'}",
    );

    for my $c (@scripts) {
        # Add the checks with their dependency information
        my $cs = $PROFILE->get_script($c);
        die "Cannot find check $c" unless defined $cs;
        my @deps = $cs->needs_info;
        $map->add('check-' . $c);
        if (@deps) {
            # In case a (third-party) check gets their needs-info wrong,
            # present the user with useful error message.
            my @missing;
            for my $dep (@deps) {
                if (!$map->known('coll-' . $dep)) {
                    push(@missing, $dep);
                }
            }
            if (@missing) {
                my $str = join(', ', @missing);
                internal_error(
                    "The check \"$c\" depends unknown collection(s): $str");
            }
            $map->addp('check-' . $c, 'coll-', @deps);
        }
    }

    # Make sure the resolver is in a sane state
    # - This can happen if we break collections (inter)dependencies.
    if ($map->missing) {
        internal_error('There are missing nodes in the resolver: '
              . join(', ', $map->missing));
    }

    my @requested;
    if ($action eq 'check') {

        # add collections requested by user (--unpack-info)
        @requested
          = map { split(/,/) } (@{$unpack_info_ref // []});

        my @unknown = grep { !collmap->getp($_) } @requested;
        die 'unrecognized items in --unpack-info:', join(SPACE, @unknown)
          if @unknown;

        # need 'override-file' for overrides
        push(@requested, 'override-file')
          unless $opt->{'no-override'};
    }

    # With --unpack we want all of them.  That's the default so,
    # "done!"

    my %override_count;

    my @sorted = sort { $a->name cmp $b->name } values %{$self->groups};
    foreach my $group (@sorted) {
        my $success = 1;

        $OUTPUT->v_msg('Starting on group ' . $group->name);

        my $total_start = [gettimeofday];
        my $group_start = [gettimeofday];

        # for checking, pass profile to limit what it unpacks
        $group->profile($PROFILE);

        $group->extra_coll(\@requested);
        $group->jobs($opt->{'jobs'});

        if (!$group->unpack($collmap, $action,$exit_code_ref, $OUTPUT)) {
            $success = 0;
        }

        my $raw_res = tv_interval($group_start);
        my $tres = sprintf('%.3fs', $raw_res);

        $OUTPUT->debug_msg(1, 'Unpack of ' . $group->name . " done ($tres)");
        $OUTPUT->perf_log($group->name . ",total-group-unpack,${raw_res}");

        if ($action eq 'check') {
            if (
                !$group->process(
                    $TAGS,$exit_code_ref, \%override_count,
                    $opt,$memory_usage, $OUTPUT
                )
            ) {
                $success = 0;
            }

            $group->clear_cache;

            if ($$exit_code_ref != 2) {
                # Double check that no processes are running;
                # hopefully it will catch regressions like 3bbcc3b
                # earlier.
                #
                # Unfortunately, the cleanup via IO::Async::Function seems keep
                # a worker unreaped; disabling. Should be revisited.
                #
                if (waitpid(-1, WNOHANG) != -1) {
                    $$exit_code_ref = 2;
                    internal_error(
                        'Unreaped processes after running checks!?');
                }
            } else {
                # If we are interrupted in (e.g.) checks/manpages, it
                # tends to leave processes behind.  No reason to flag
                # an error for that - but we still try to reap the
                # children if they are now done.

                1 while waitpid(-1, WNOHANG) > 0;
            }
        }

        # remove group files unless we are keeping the lab
        $group->clean_lab($OUTPUT)
          unless ($self->keep);

       # Wait for any remaining jobs - There will usually not be any
       # unless we had an issue examining the last package.  We patiently wait
       # for them here; if the user cannot be bothered to wait, he/she can send
       # us a signal and the END handler will kill any remaining jobs.

        $group->wait_for_jobs;

        my $total_raw_res = tv_interval($total_start);
        my $total_tres = sprintf('%.3fs', $total_raw_res);

        if ($success) {
            print {$STATUS_FD} 'complete ' . $group->name . " ($total_tres)\n";
        } else {
            print {$STATUS_FD} 'error ' . $group->name . " ($total_tres)\n";
        }
        $OUTPUT->v_msg('Finished processing group ' . $group->name);
    }

    # do not remove lab if so selected
    $self->keep($opt->{'keep-lab'});

    if (    $action eq 'check'
        and not $opt->{'no-override'}
        and not $opt->{'show-overrides'}) {

        my $errors = $override_count{errors} || 0;
        my $warnings = $override_count{warnings} || 0;
        my $info = $override_count{info} || 0;
        my $total = $errors + $warnings + $info;

        my $unused = $override_count{unused} || 0;

        if ($total > 0 or $unused > 0) {
            my $text
              = ($total == 1)
              ? "$total tag overridden"
              : "$total tags overridden";
            my @output;
            if ($errors) {
                push(@output,
                    ($errors == 1) ? "$errors error" : "$errors errors");
            }
            if ($warnings) {
                push(@output,
                    ($warnings == 1)
                    ? "$warnings warning"
                    : "$warnings warnings");
            }
            if ($info) {
                push(@output, "$info info");
            }
            if (@output) {
                $text .= ' (' . join(', ', @output). ')';
            }
            if ($unused == 1) {
                $text .= "; $unused unused override";
            } elsif ($unused > 1) {
                $text .= "; $unused unused overrides";
            }
            $OUTPUT->msg($text);
        }
    }

    my $ign_over = $override_count{ignored};
    if (keys %$ign_over) {
        $OUTPUT->msg(
            join(q{ },
                'Some overrides were ignored,',
                'since the tags were marked "non-overridable".'));
        if ($opt->{'verbose'}) {
            $OUTPUT->v_msg(
                join(q{ },
                    'The following tags were "non-overridable"',
                    'and had at least one override'));
            foreach my $tag (sort keys %$ign_over) {
                $OUTPUT->v_msg("  - $tag");
            }
        } else {
            $OUTPUT->msg('Use --verbose for more information.');
        }
    }

    return;
}

=item $pool->get_group_names

Returns the name of all the groups in this pool.

Do not modify the list nor its contents.

=cut

sub get_group_names{
    my ($self) = @_;
    return keys %{ $self->groups };
}

=item $pool->get_group($name)

Returns the group called $name or C<undef>
if there is no group called $name.

=cut

sub get_group{
    my ($self, $group) = @_;
    return $self->groups->{$group};
}

=item $pool->empty

Returns true if the pool is empty.

=cut

sub empty{
    my ($self) = @_;
    return scalar keys %{$self->groups} == 0;
}

=item DEMOLISH

Removes the lab and everything in it.  Any reference to an entry
returned from this lab will immediately become invalid.

=cut

sub DEMOLISH {
    my ($self, $in_global_destruction) = @_;

    path($self->basedir)->remove_tree
      if length $self->basedir && -d $self->basedir && !$self->keep;

    return;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable>

L<Lintian::Processable::Group>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

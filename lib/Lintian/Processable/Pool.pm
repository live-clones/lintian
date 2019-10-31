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

use Moo;

use Carp qw(croak);
use Cwd();
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use POSIX qw(:sys_wait_h);

use Lintian::DepMap;
use Lintian::DepMap::Properties;
use Lintian::Output qw(:messages);
use Lintian::Processable::Group;
use Lintian::Unpacker;
use Lintian::Util;

use constant SPACE => q{ };

has groups => (is => 'rwp', default => sub{ {} });
has unpacker => (is => 'rwp');
has lab => (is => 'rw', default => sub { Lintian::Lab->new });

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
        $exit_code_ref, $overrides,$opt,$memory_usage,
        $STATUS_FD, $unpack_info_ref
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

        debug_msg(2, 'Read collector description for ' . $cs->name . '...');
        $collmap->add($cs->name, $cs->needs_info, $cs);
        $map->addp('coll-' . $cs->name, 'coll-', $cs->needs_info);
    }

    closedir($dir)
      or warn 'Close failed';

    my @scripts = sort $PROFILE->scripts;
    debug_msg(
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

    my $unpacker = Lintian::Unpacker->new;

    # for checking, pass profile to limit what it unpacks
    if ($action eq 'check') {

        $unpacker->profile($PROFILE);

        # add collections requested by user (--unpack-info)
        my @requested
          = map { split(/,/) } (@{$unpack_info_ref // []});

        my @unknown = grep { !collmap->getp($_) } @requested;
        die 'unrecognized items in --unpack-info:', join(SPACE, @unknown)
          if @unknown;

        # need 'override-file' for overrides
        push(@requested, 'override-file')
          unless $opt->{'no-override'};

        $unpacker->extra_coll(\@requested);
    }

    # With --unpack we want all of them.  That's the default so,
    # "done!"

    $unpacker->jobs($opt->{'jobs'});
    $unpacker->init($collmap);
    $self->_set_unpacker($unpacker);

    my @sorted = sort { $a->name cmp $b->name } values %{$self->groups};
    foreach my $group (@sorted) {
        my $success = 1;

        v_msg('Starting on group ' . $group->name);

        my $total_start = [gettimeofday];
        my $group_start = [gettimeofday];

        if (!$group->unpack($self->unpacker, $action,$exit_code_ref)) {
            $success = 0;
        }

        my $raw_res = tv_interval($group_start);
        my $tres = sprintf('%.3fs', $raw_res);

        debug_msg(1, 'Unpack of ' . $group->name . " done ($tres)");
        perf_log($group->name . ",total-group-unpack,${raw_res}");

        if ($action eq 'check') {
            if (
                !$group->process(
                    $PROFILE,$TAGS, $collmap,
                    $exit_code_ref, $overrides,$opt,
                    $memory_usage
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
        $group->clean_lab
          unless ($self->lab->keep);

        my $total_raw_res = tv_interval($total_start);
        my $total_tres = sprintf('%.3fs', $total_raw_res);

        if ($success) {
            print {$STATUS_FD} 'complete ' . $group->name . " ($total_tres)\n";
        } else {
            print {$STATUS_FD} 'error ' . $group->name . " ($total_tres)\n";
        }
        v_msg('Finished processing group ' . $group->name);
    }

    # Wait for any remaining jobs - There will usually not be any
    # unless we had an issue examining the last package.  We patiently wait
    # for them here; if the user cannot be bothered to wait, he/she can send
    # us a signal and the END handler will kill any remaining jobs.

    $self->unpacker->wait_for_jobs;

    # do not remove lab if so selected
    $self->lab->keep($opt->{'keep-lab'});

    return;
}

=item DEMOLISH

Moo destructor.

=cut

sub DEMOLISH {
    my ($self, $in_global_destruction) = @_;

    # kill any remaining jobs.
    $self->unpacker->kill_jobs
      if $self->unpacker;

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
    return scalar %{$self->groups} == 0;
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

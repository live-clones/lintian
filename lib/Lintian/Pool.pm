# Copyright © 2011 Niels Thykier <niels@thykier.net>
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

## Represents a pool of processables (Lintian::Processable)
package Lintian::Pool;

use v5.20;
use warnings;
use utf8;
use autodie;

use Carp qw(croak);
use Cwd;
use List::MoreUtils qw(any);
use Time::HiRes qw(gettimeofday tv_interval);
use Path::Tiny;
use POSIX qw(:sys_wait_h);

use Lintian::Group;
use Lintian::Util;

use constant EMPTY => q{};
use constant SPACE => q{ };

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Pool -- Pool of processables

=head1 SYNOPSIS

 use Lintian::Pool;
 
 my $pool = Lintian::Pool->new;
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

=item C<savedir>

=cut

has groups => (is => 'rwp', default => sub{ {} });

has savedir => (is => 'rw', default => sub{ getcwd; });

# must be absolute; frontend/lintian depends on it
has basedir => (
    is => 'rwp',
    default => sub {

        my $absolute
          = Path::Tiny->tempdir(TEMPLATE => 'lintian-pool-XXXXXXXXXX');

        $absolute->mkpath({mode => 0777});

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
    my ($self, $PROFILE, $exit_code_ref, $option, $STATUS_FD, $OUTPUT)= @_;

    my %override_count;
    my %ignored_overrides;
    my $unused_overrides = 0;

    # do not remove lab if so selected
    $self->keep($option->{'keep-lab'} // 0);

    for my $group (values %{$self->groups}) {

        $OUTPUT->v_msg('Starting on group ' . $group->name);

        my $total_start = [gettimeofday];
        my $group_start = [gettimeofday];

        $group->profile($PROFILE);
        $group->jobs($option->{'jobs'});

        $group->unpack($OUTPUT);

        my $raw_res = tv_interval($group_start);
        my $tres = sprintf('%.3fs', $raw_res);

        $OUTPUT->debug_msg(1, 'Unpack of ' . $group->name . " done ($tres)");
        $OUTPUT->perf_log($group->name . ",total-group-unpack,${raw_res}");

        my %reported_count;

        my $success= $group->process(\%ignored_overrides, $option, $OUTPUT);

        # associate all tags with processable
        for my $processable ($group->get_processables){
            $_->processable($processable) for @{$processable->tags};
        }

        my @tags = map { @{$_->tags} } $group->get_processables;

        # remove circular references
        $_->tags([]) for $group->get_processables;

        my @reported = grep { !$_->override } @tags;
        my @reported_trusted = grep { !$_->info->experimental } @reported;
        my @reported_experimental = grep { $_->info->experimental } @reported;

        my @override = grep { $_->override } @tags;
        my @override_trusted = grep { !$_->info->experimental } @override;
        my @override_experimental = grep { $_->info->experimental } @override;

        $unused_overrides+= scalar grep {
                 $_->name eq 'mismatched-override'
              || $_->name eq 'unused-override'
        } @tags;

        $reported_count{$_->info->effective_severity}++ for @reported_trusted;
        $reported_count{experimental} += scalar @reported_experimental;
        $reported_count{override} += scalar @override;

        unless ($option->{'no-override'} || $option->{'show-overrides'}) {

            $override_count{$_->info->effective_severity}++
              for @override_trusted;
            $override_count{experimental} += scalar @override_experimental;
        }

        $$exit_code_ref = 2
          if $success && any { $reported_count{$_} } @{$option->{'fail-on'}};

        # discard disabled tags
        @tags= grep { $PROFILE->tag_is_enabled($_->name) } @tags;

        # discard experimental tags
        @tags = grep { !$_->info->experimental } @tags
          unless $option->{'display-experimental'};

        # discard overridden tags
        @tags = grep { !defined $_->override } @tags
          unless $option->{'show-overrides'};

        # discard outside the selected display level
        @tags= grep { $PROFILE->display_level_for_tag($_->name) }@tags;

        my $reference_limit = $option->{'display-source'} // [];
        if (@{$reference_limit}) {

            my @topic_tags;
            for my $tag (@tags) {
                my @references = split(/,/, $tag->info->references);

                # retain the first word
                s/^([\w-]+)\s.*/$1/ for @references;

                # remove anything in parentheses at the end
                s/\(\S+\)$// for @references;

                # check if tag refers to the selected references
                my $referencelc
                  = List::Compare->new(\@references, $reference_limit);
                next
                  unless $referencelc->get_intersection;

                push(@topic_tags, $tag);
            }

            @tags = @topic_tags;
        }

        # put tags back into their respective processables
        push(@{$_->processable->tags}, $_) for @tags;

        if ($$exit_code_ref != 1) {
            # Double check that no processes are running;
            # hopefully it will catch regressions like 3bbcc3b
            # earlier.
            #
            # Unfortunately, the cleanup via IO::Async::Function seems keep
            # a worker unreaped; disabling. Should be revisited.
            #
            if (waitpid(-1, WNOHANG) != -1) {
                $$exit_code_ref = 1;
                die 'Unreaped processes after running checks!?';
            }
        } else {
            # If we are interrupted in (e.g.) checks/manpages, it
            # tends to leave processes behind.  No reason to flag
            # an error for that - but we still try to reap the
            # children if they are now done.

            1 while waitpid(-1, WNOHANG) > 0;
        }

        # remove group files
        $group->clean_lab($OUTPUT);

        my $total_raw_res = tv_interval($total_start);
        my $total_tres = sprintf('%.3fs', $total_raw_res);

        if ($success) {
            print {$STATUS_FD} 'complete ' . $group->name . " ($total_tres)\n";
        } else {
            print {$STATUS_FD} 'error ' . $group->name . " ($total_tres)\n";
            $$exit_code_ref = 1;
        }
        $OUTPUT->v_msg('Finished processing group ' . $group->name);
    }

    # pass everything, in case some groups or processables have no tags
    $OUTPUT->issue_tags([values %{$self->groups}]);

    unless ($option->{'no-override'}
        || $option->{'show-overrides'}) {

        my $errors = $override_count{error} // 0;
        my $warnings = $override_count{warning} // 0;
        my $info = $override_count{info} // 0;
        my $total = $errors + $warnings + $info;

        if ($total > 0 or $unused_overrides > 0) {

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

            if ($unused_overrides == 1) {
                $text .= "; $unused_overrides unused override";
            } elsif ($unused_overrides > 1) {
                $text .= "; $unused_overrides unused overrides";
            }

            $OUTPUT->msg($text);
        }
    }

    if (keys %ignored_overrides) {
        $OUTPUT->msg(
'Some overrides were ignored, since the tags were marked non-overridable.'
        );
        if ($option->{'verbose'}) {
            $OUTPUT->v_msg(
'The following tags had at least one override but are non-overridable:'
            );
            $OUTPUT->v_msg("  - $_") for sort keys %ignored_overrides;
        } else {
            $OUTPUT->msg('Use --verbose for more information.');
        }
    }

    path($self->basedir)->remove_tree
      if length $self->basedir && -d $self->basedir;

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

    # change back to where we were; otherwise removal may fail
    chdir($self->savedir);

    path($self->basedir)->remove_tree
      if length $self->basedir && -d $self->basedir;

    return;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Processable>

L<Lintian::Group>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

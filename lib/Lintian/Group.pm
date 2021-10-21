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

package Lintian::Group;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use Cwd;
use Devel::Size qw(total_size);
use File::Spec;
use List::Compare;
use List::SomeUtils qw(any none uniq firstval);
use POSIX qw(ENOENT);
use Time::HiRes qw(gettimeofday tv_interval);
use Time::Piece;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Util qw(human_bytes);

use Moo;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $UNDERSCORE => q{_};

const my $EXTRA_VERBOSE => 3;

# A private table of supported types.
my %SUPPORTED_TYPES = (
    'binary'  => 1,
    'buildinfo' => 1,
    'changes' => 1,
    'source'  => 1,
    'udeb'    => 1,
);

=head1 NAME

Lintian::Group -- A group of objects that Lintian can process

=head1 SYNOPSIS

 use Lintian::Group;

 my $group = Lintian::Group->new('lintian_2.5.0_i386.changes');

=head1 DESCRIPTION

Instances of this perl class are sets of
L<processables|Lintian::Processable>.  It allows at most one source
and one changes or buildinfo package per set, but multiple binary packages
(provided that the binary is not already in the set).

=head1 METHODS

=over 4

=item $group->pooldir

Returns or sets the pool directory used by this group.

=item $group->source_name

=item $group->source_version

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

=item processing_start

=item processing_end

=item cache

Cache for some items.

=item profile

Hash with active jobs.

=item C<saved_direct_dependencies>

=item C<saved_direct_reliants>

=cut

has pooldir => (is => 'rw', default => $EMPTY);
has source_name => (is => 'rw', default => $EMPTY);
has source_version => (is => 'rw', default => $EMPTY);

has binary => (is => 'rw', default => sub{ {} });
has buildinfo => (is => 'rw');
has changes => (is => 'rw');
has source => (is => 'rw');
has udeb => (is => 'rw', default => sub{ {} });

has jobs => (is => 'rw', default => 1);
has processing_start => (is => 'rw', default => $EMPTY);
has processing_end => (is => 'rw', default => $EMPTY);

has cache => (is => 'rw', default => sub { {} });
has profile => (is => 'rw', default => sub { {} });

=item $group->name

Returns a unique identifier for the group based on source and version.

=cut

sub name {
    my ($self) = @_;

    return $EMPTY
      unless length $self->source_name && length $self->source_version;

    return $self->source_name . $UNDERSCORE . $self->source_version;
}

=item process

Process group.

=cut

sub process {
    my ($self, $ignored_overrides, $option)= @_;

    my $groupname = $self->name;
    local $SIG{__WARN__}
      = sub { warn encode_utf8("Warning in group $groupname: $_[0]") };

    my $savedir = getcwd;

    $self->processing_start(gmtime->datetime . 'Z');
    say {*STDERR} encode_utf8('Starting on group ' . $self->name)
      if $option->{debug};
    my $group_timer = [gettimeofday];

    my $success = 1;
    for my $processable ($self->get_processables){

        my $path = $processable->path;
        local $SIG{__WARN__}
          = sub { warn encode_utf8("Warning in processable $path: $_[0]") };

        my $declared_overrides;

        say {*STDERR}
          encode_utf8(
            'Base directory for processable: '. $processable->basedir)
          if $option->{debug};

        unless ($option->{'no-override'}) {

            say {*STDERR} encode_utf8('Loading overrides file (if any) ...')
              if $option->{debug};

            eval {$declared_overrides = $processable->overrides;};
            if (my $err = $@) {
                die encode_utf8($err) if not ref $err or $err->errno != ENOENT;
            }

            my %alias = %{$self->profile->known_aliases};
            my @renamed_overrides
              = grep { length $alias{$_} } keys %{$declared_overrides};

            # treat renamed tags in overrides
            for my $dated (@renamed_overrides) {

                # get new name
                my $modern = $alias{$dated};

                # make space for renamed override
                $declared_overrides->{$modern} //= {};

                for my $context (keys %{$declared_overrides->{$dated}}) {

                    # alert user to new tag name
                    $processable->hint('renamed-tag',
                        "$dated => $modern in line "
                          .$declared_overrides->{$dated}{$context}{line});

                    if (exists $declared_overrides->{$modern}{$context}) {

                        my @lines = (
                            $declared_overrides->{$dated}{$context}{line},
                            $declared_overrides->{$modern}{$context}{line});
                        $processable->hint('duplicate-override-context',
                            $modern, 'lines', sort @lines);

                        next;
                    }

                    # transfer context to current tag name
                    $declared_overrides->{$modern}{$context}
                      = $declared_overrides->{$dated}{$context};

                    # remember old tagname
                    $declared_overrides->{$modern}{$context}{'renamed-from'}
                      = $dated;

                    # remove the old override context
                    delete $declared_overrides->{$dated}{$context};
                }

                # remove the alias override if there are no contexts left
                delete $declared_overrides->{$dated}
                  unless %{$declared_overrides->{$dated}};
            }

            # complain about and filter out unknown tags in overrides
            my @unknown_overrides = grep { !$self->profile->get_tag($_) }
              keys %{$declared_overrides};
            for my $tagname (@unknown_overrides) {

                $processable->hint('malformed-override',
                    "Unknown tag $tagname in line "
                      . $declared_overrides->{$tagname}{$_}{line})
                  for keys %{$declared_overrides->{$tagname}};

                delete $declared_overrides->{$tagname};
            }

            # treat ignored overrides here
            for my $tagname (keys %{$declared_overrides}) {

                unless ($self->profile->is_overridable($tagname)) {
                    delete $declared_overrides->{$tagname};
                    $ignored_overrides->{$tagname}++;
                }
            }
        }

        my @check_names = sort $self->profile->enabled_checks;
        for my $name (@check_names) {

            my $timer = [gettimeofday];
            my $procid = $processable->identifier;
            say {*STDERR} encode_utf8("Running check: $name on $procid  ...")
              if $option->{debug};

            my $absolute = $self->profile->check_path_by_name->{$name};
            require $absolute;

            my $module = $self->profile->check_module_by_name->{$name};
            my $check = $module->new;

            $check->name($name);
            $check->processable($processable);
            $check->group($self);
            $check->profile($self->profile);

            eval { $check->run };
            my $err = $@;
            my $raw_res = tv_interval($timer);

            if ($err) {
                my $message = $err;
                $message
                  .= "warning: cannot run $name check on package $procid\n";
                $message .= "skipping check of $procid\n";
                warn encode_utf8($message);

                $success = 0;

                next;
            }

            my $tres = sprintf('%.3fs', $raw_res);
            say {*STDERR} encode_utf8("Check $name for $procid done ($tres)")
              if $option->{debug};
            say {*STDERR} encode_utf8("$procid,check/$name,$raw_res")
              if $option->{'perf-output'};
        }

        my @crossing;

        my $hints = $processable->hints;
        $processable->hints([]);

        for my $hint (@{$hints}) {

            next
              if $hint->tag->show_always;

            my @matches = grep { $_->suppress($processable, $hint->context) }
              @{$hint->tag->screens};
            next
              unless @matches;

            my @sorted = sort { $a->name cmp $b->name } @matches;

            push(@crossing,
                    $hint->tag->name
                  . $SPACE
                  . join($SPACE, map { $_->name } @sorted))
              if @sorted > 1;

            my $screen = $sorted[0];
            $hint->screen($screen);
        }

        $processable->hints($hints);

        $processable->hint('crossing-screens', $_) for @crossing;

        my %used_overrides;

        my @keep_hints;
        for my $hint (@{$processable->hints}) {

            my $declared = $declared_overrides->{$hint->tag->name};
            if ($declared && !$hint->tag->show_always) {

                # empty context in specification matches all
                my $override = $declared->{$EMPTY};

                # matches context exactly
                $override = $declared->{$hint->context}
                  unless $override;

                # look for patterns
                unless ($override) {
                    my @candidates
                      = sort grep { length $declared->{$_}{pattern} }
                      keys %{$declared};

                    my $match= firstval {
                        $hint->context =~ m/^$declared->{$_}{pattern}\z/
                    }
                    @candidates;

                    $override = $declared->{$match}
                      if $match;
                }

                # new hash keys are autovivified to 0
                $used_overrides{$hint->tag->name}{$override->{context}}++
                  if $override;

                $hint->override($override);
            }

            push(@keep_hints, $hint);
        }

        $processable->hints(\@keep_hints);

        my %otherwise_visible = map { $_->tag->name => 1 } @keep_hints;

        # look for unused overrides
        for my $tagname (keys %{$declared_overrides}) {

            next
              unless $self->profile->tag_is_enabled($tagname);

            my @declared_contexts = keys %{$declared_overrides->{$tagname}};
            my @used_contexts = keys %{$used_overrides{$tagname} // {}};

            my $context_lc
              = List::Compare->new(\@declared_contexts, \@used_contexts);
            my @unused_contexts = $context_lc->get_Lonly;

            # cannot be overridden or suppressed
            my $condition = 'unused-override';
            $condition = 'mismatched-override'
              if $otherwise_visible{$tagname};

            for my $context (@unused_contexts) {

                # for renames, use the original name from overrides
                my $original_name
                  = $declared_overrides->{$tagname}{$context}{'renamed-from'}
                  // $tagname;

                $processable->hint($condition, $original_name, $context);
            }
        }
    }

    $self->processing_end(gmtime->datetime . 'Z');

    my $raw_res = tv_interval($group_timer);
    my $tres = sprintf('%.3fs', $raw_res);
    say {*STDERR}
      encode_utf8('Checking all of group ' . $self->name . " done ($tres)")
      if $option->{debug};
    say {*STDERR} encode_utf8($self->name . ",total-group-check,$raw_res")
      if $option->{'perf-output'};

    if ($option->{'debug'} > 2) {

        # suppress warnings without reliable sizes
        local $Devel::Size::warn = 0;

        my $pivot = ($self->get_processables)[0];
        my $group_id
          = $pivot->source_name . $UNDERSCORE . $pivot->source_version;
        my $group_usage
          = human_bytes(total_size([map { $_ } $self->get_processables]));
        say {*STDERR}
          encode_utf8("Memory usage [group:$group_id]: $group_usage")
          if $option->{debug} >= $EXTRA_VERBOSE;

        for my $processable ($self->get_processables) {
            my $id = $processable->identifier;
            my $usage = human_bytes(total_size($processable));

            say {*STDERR} encode_utf8("Memory usage [$id]: $usage")
              if $option->{debug} >= $EXTRA_VERBOSE;
        }
    }

    # change to known folder; ealier failures could prevent removal below
    chdir $savedir
      or warn encode_utf8("Cannot change to directory $savedir");

    $self->clean_lab($option);

    return $success;
}

=item clean_lab

Removes the lab files to conserve disk space. Global destruction will
also get these unless we are keeping the lab.

=cut

sub clean_lab {
    my ($self, $option) = @_;

    my $total = [gettimeofday];

    for my $processable ($self->get_processables) {

        my $proc_id = $processable->identifier;
        say {*STDERR} encode_utf8("Auto removing: $proc_id ...")
          if $option->{debug};

        my $each = [gettimeofday];

        $processable->remove;

        my $raw_res = tv_interval($each);
        say {*STDERR} encode_utf8("Auto removing: $proc_id done (${raw_res}s)")
          if $option->{debug};
        say {*STDERR} encode_utf8("$proc_id,auto-remove entry,$raw_res")
          if $option->{'perf-output'};
    }

    my $raw_res = tv_interval($total);
    my $tres = sprintf('%.3fs', $raw_res);
    say {*STDERR}
      encode_utf8(
        'Auto-removal all for group ' . $self->name . " done ($tres)")
      if $option->{debug};
    say {*STDERR}encode_utf8($self->name . ",total-group-auto-remove,$raw_res")
      if $option->{'perf-output'};

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

sub add_processable {
    my ($self, $processable) = @_;

    if ($processable->tainted) {
        warn encode_utf8(
            sprintf(
                "warning: tainted %1\$s package '%2\$s', skipping\n",
                $processable->type, $processable->name
            ));
        return 0;
    }

    $self->source_name($processable->source_name)
      unless length $self->source_name;
    $self->source_version($processable->source_version)
      unless length $self->source_version;

    return 0
      if $self->source_name ne $processable->source_name
      || $self->source_version ne $processable->source_version;

    croak encode_utf8('Please set pool directory first.')
      unless $self->pooldir;

    $processable->pooldir($self->pooldir);

    # needed to read tag specifications and error reporting
    croak encode_utf8('Please set profile first.')
      unless $self->profile;

    $processable->profile($self->profile);

    croak encode_utf8('Not a supported type (' . $processable->type . ')')
      unless exists $SUPPORTED_TYPES{$processable->type};

    if ($processable->type eq 'changes') {
        die encode_utf8('Cannot add another ' . $processable->type . ' file')
          if $self->changes;
        $self->changes($processable);

    } elsif ($processable->type eq 'buildinfo') {
        # Ignore multiple .buildinfo files; use the first one
        $self->buildinfo($processable)
          unless $self->buildinfo;

    } elsif ($processable->type eq 'source'){
        die encode_utf8('Cannot add another source package')
          if $self->source;
        $self->source($processable);

    } else {
        my $type = $processable->type;
        die encode_utf8('Unknown type ' . $type)
          unless $type eq 'binary' || $type eq 'udeb';

        # check for duplicate; should be rewritten with arrays
        my $id = $processable->identifier;
        return 0
          if exists $self->$type->{$id};

        $self->$type->{$id} = $processable;
    }

    return 1;
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
        die encode_utf8("Unknown type of processable: $type");
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

=item direct_dependencies (PROC)

If PROC is a part of the underlying processable group, this method
returns a listref containing all the direct dependencies of PROC.  If
PROC is not a part of the group, this returns undef.

Note: Only strong dependencies (Pre-Depends and Depends) are
considered.

Note: Self-dependencies (if any) are I<not> included in the result.

=cut

has saved_direct_dependencies => (is => 'rw', default => sub { {} });

sub direct_dependencies {
    my ($self, $processable) = @_;

    unless (keys %{$self->saved_direct_dependencies}) {

        my @processables = $self->get_processables('binary');
        push @processables, $self->get_processables('udeb');

        my %dependencies;
        foreach my $that (@processables) {

            my $relation = $that->relation('strong');
            my @specific;

            foreach my $this (@processables) {

                # Ignore self deps - we have checks for that and it
                # will just end up complicating "correctness" of
                # otherwise simple checks.
                next
                  if $this->name eq $that->name;

                push @specific, $this
                  if $relation->satisfies($this->name);
            }
            $dependencies{$that->name} = \@specific;
        }

        $self->saved_direct_dependencies(\%dependencies);
    }

    return $self->saved_direct_dependencies->{$processable->name}
      if $processable;

    return $self->saved_direct_dependencies;
}

=item direct_reliants (PROC)

If PROC is a part of the underlying processable group, this method
returns a listref containing all the packages in the group that rely
on PROC.  If PROC is not a part of the group, this returns undef.

Note: Only strong dependencies (Pre-Depends and Depends) are
considered.

Note: Self-dependencies (if any) are I<not> included in the result.

=cut

has saved_direct_reliants => (is => 'rw', default => sub { {} });

sub direct_reliants {
    my ($self, $processable) = @_;

    unless (keys %{$self->saved_direct_reliants}) {

        my @processables = $self->get_processables('binary');
        push @processables, $self->get_processables('udeb');

        my %reliants;
        foreach my $that (@processables) {

            my @specific;
            foreach my $this (@processables) {

                # Ignore self deps - we have checks for that and it
                # will just end up complicating "correctness" of
                # otherwise simple checks.
                next
                  if $this->name eq $that->name;

                my $relation = $this->relation('strong');
                push @specific, $this
                  if $relation->satisfies($that->name);
            }
            $reliants{$that->name} = \@specific;
        }

        $self->saved_direct_reliants(\%reliants);
    }

    return $self->saved_direct_reliants->{$processable->name}
      if $processable;

    return $self->saved_direct_reliants;
}

=item spelling_exceptions

Returns a hashref of words, which the spell checker should ignore.
These words are generally based on the package names in the group to
avoid false-positive "spelling error" when packages have "fun" names.

Example: Package alot-doc (#687464)

=cut

has spelling_exceptions => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %exceptions;

        for my $processable ($self->get_processables) {

            my @names = ($processable->name, $processable->source_name);
            push(@names, $processable->debian_control->installables)
              if $processable->type eq 'source';

            foreach my $name (@names) {
                $exceptions{$name} = 1;
                $exceptions{$_} = 1 for split m/-/, $name;
            }
        }

        return \%exceptions;
    });

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

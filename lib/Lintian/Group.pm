# Copyright © 2011 Niels Thykier <niels@thykier.net>
# Copyright © 2019-2021 Felix Lechner
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
use List::SomeUtils qw(any none uniq firstval true);
use POSIX qw(ENOENT);
use Syntax::Keyword::Try;
use Time::HiRes qw(gettimeofday tv_interval);
use Time::Piece;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Hint::Pointed;
use Lintian::Util qw(human_bytes);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $UNDERSCORE => q{_};

const my $EXTRA_VERBOSE => 3;

# A private table of supported types.
const my %SUPPORTED_TYPES => (
    'binary'  => 1,
    'buildinfo' => 1,
    'changes' => 1,
    'source'  => 1,
    'udeb'    => 1,
);

use Moo;
use namespace::clean;

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

        my @hints;
        my %enabled_overrides;

        say {*STDERR}
          encode_utf8(
            'Base directory for processable: '. $processable->basedir)
          if $option->{debug};

        unless ($option->{'no-override'}) {

            say {*STDERR} encode_utf8('Loading overrides file (if any) ...')
              if $option->{debug};

            my %alias = %{$self->profile->known_aliases};
            for my $override (@{$processable->overrides}) {

                my $pattern = $override->pattern;

                # catch renames
                my $tag_name = $override->tag_name;
                $tag_name = $alias{$tag_name}
                  if length $alias{$tag_name};

                # also catches unknown tags
                next
                  unless $self->profile->tag_is_enabled($tag_name);

                my @architectures = @{$override->architectures};

                # count negations
                my $negations = true { /^!/ } @architectures;

                # strip negations if present
                s/^!// for @architectures;

                # enable overrides for this architecture
                # proceed when none specified
                next
                  if @architectures
                  && (
                    $negations xor none {
                        $self->profile->architectures->restriction_matches($_,
                            $processable->architecture)
                    }
                    @architectures
                  );

                if (!$self->profile->is_overridable($tag_name)) {
                    ++$ignored_overrides->{$tag_name};
                    next;
                }

                $enabled_overrides{$tag_name}{$pattern} = $override;
            }
        }

        my @from_checks;

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

            try {
                my @found_here = $check->run;
                push(@from_checks, @found_here);

            } catch {
                my $message = $@;
                $message
                  .= "warning: cannot run $name check on package $procid\n";
                $message .= "skipping check of $procid\n";
                warn encode_utf8($message);

                $success = 0;

                next;
            }

            my $raw_res = tv_interval($timer);
            my $tres = sprintf('%.3fs', $raw_res);

            say {*STDERR} encode_utf8("Check $name for $procid done ($tres)")
              if $option->{debug};
            say {*STDERR} encode_utf8("$procid,check/$name,$raw_res")
              if $option->{'perf-output'};
        }

        my %context_tracker;
        my %used_overrides;
        my %otherwise_visible;

        for my $hint (@from_checks) {

            my $tag_name = $hint->tag_name;

            croak encode_utf8('No tag name')
              unless length $tag_name;

            my $issuer = $hint->issued_by;

            # try local name space
            my $tag = $self->profile->get_tag("$issuer/$tag_name");

            warn encode_utf8(
"Using tag $tag_name as name spaced while not so declared (in check $issuer)."
            )if defined $tag && !$tag->name_spaced;

            # try global name space
            $tag ||= $self->profile->get_tag($tag_name);

            unless (defined $tag) {
                warn encode_utf8(
                    "Tried to issue unknown tag $tag_name in check $issuer.");
                next;
            }

            my $owner = $tag->check;
            if ($issuer ne $owner) {
                warn encode_utf8(
                    "Check $issuer has no tag $tag_name (but $owner does).");
                next;
            }

            # pull name from tag; could be name-spaced
            $hint->tag_name($tag->name);
            $tag_name = $hint->tag_name;

            # skip disabled tags
            next
              unless $self->profile->tag_is_enabled($tag_name);

            my $context = $hint->context;

            if (exists $context_tracker{$tag_name}{$context}) {
                warn encode_utf8(
"Tried to issue duplicate hint in check $issuer: $tag_name $context\n"
                );
                next;
            }

            $context_tracker{$tag_name}{$context} = 1;

            my @masks
              = grep { $_->suppress($processable, $hint) } @{$tag->screens};

            my @mask_names = map { $_->name } @masks;
            my $mask_list = join($SPACE, (sort @mask_names));

            warn encode_utf8("Crossing screens for $tag_name ($mask_list)")
              if @masks > 1;

            $hint->masks(\@masks)
              if !$tag->show_always;

            my $declared = $enabled_overrides{$tag->name};
            if ($declared && !$tag->show_always) {

                # empty context in specification matches all
                my $override = $declared->{$EMPTY};

                # matches context exactly
                $override = $declared->{$hint->context}
                  unless $override;

                # look for patterns
                unless ($override) {
                    my @candidates= sort grep { length $declared->{$_}->regex }
                      keys %{$declared};

                    my %regexes;
                    $regexes{$_} = $declared->{$_}->regex for @candidates;

                    my $match= firstval {
                        $hint->context =~ m/^$regexes{$_}\z/
                    }
                    @candidates;

                    $override = $declared->{$match}
                      if $match;
                }

                # new hash values are autovivified to 0
                $used_overrides{$tag->name}{$override->pattern}++
                  if $override;

                $hint->override($override);
            }

            $otherwise_visible{$tag->name} = 1;

            push(@hints, $hint);
        }

        # look for unused overrides
        for my $tag_name (keys %enabled_overrides) {

            my @declared_patterns = keys %{$enabled_overrides{$tag_name}};
            my @used_patterns = keys %{$used_overrides{$tag_name} // {}};

            my $pattern_lc
              = List::Compare->new(\@declared_patterns, \@used_patterns);
            my @unused_patterns = $pattern_lc->get_Lonly;

            for my $pattern (@unused_patterns) {

                my $override = $enabled_overrides{$tag_name}{$pattern};

                my $override_item = $processable->override_file;
                my $position = $override->position;
                my $pointer = $override_item->pointer($position);

                my $unused = Lintian::Hint::Pointed->new;
                $unused->issued_by('lintian');

                $unused->tag_name('unused-override');
                $unused->tag_name('mismatched-override')
                  if $otherwise_visible{$tag_name};

                # use the original name, in case the tag was renamed
                my $original_name = $override->tag_name;
                $unused->note("$original_name $pattern");

                $unused->pointer($pointer);

                # cannot be overridden or suppressed
                push(@hints, $unused);
            }
        }

        # carry hints into the output modules
        $processable->hints(\@hints);
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

        my @processables = $self->get_processables;
        my $pivot = shift @processables;
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

    return $success;
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

=item get_processables

Returns an array of all processables in $group.

=cut

sub get_processables {
    my ($self) = @_;

    my @processables;

    push(@processables, $self->changes)
      if defined $self->changes;

    push(@processables, $self->source)
      if defined $self->source;

    push(@processables, $self->buildinfo)
      if defined $self->buildinfo;

    push(@processables, $self->get_installables);

    return @processables;
}

=item get_installables

Returns all binary (and udeb) processables in $group.

If $group does not have any binary processables then an empty list is
returned.

=cut

sub get_installables {
    my ($self) = @_;

    my @installables;

    push(@installables, values %{$self->binary});
    push(@installables, values %{$self->udeb});

    return @installables;
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

        my @processables = $self->get_installables;

        my %dependencies;
        for my $that (@processables) {

            my $relation = $that->relation('strong');
            my @specific;

            for my $this (@processables) {

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

        my @processables = $self->get_installables;

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

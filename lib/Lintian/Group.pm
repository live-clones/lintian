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
use autodie;

use Carp qw(croak);
use Devel::Size qw(total_size);
use File::Spec;
use List::Compare;
use List::MoreUtils qw(uniq firstval);
use Path::Tiny;
use POSIX qw(ENOENT);
use Time::HiRes qw(gettimeofday tv_interval);
use Time::Piece;

use Lintian::Processable::Binary;
use Lintian::Processable::Buildinfo;
use Lintian::Processable::Changes;
use Lintian::Processable::Source;
use Lintian::Processable::Udeb;
use Lintian::Util qw(human_bytes);

use constant EMPTY => q{};
use constant SPACE => q{ };

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

=item processing_start

=item processing_end

=item cache

Cache for some items.

=item profile

Hash with active jobs.

=item C<saved_direct_dependencies>

=item C<saved_direct_reliants>

=cut

has pooldir => (is => 'rw', default => EMPTY);
has name => (is => 'rw', default => EMPTY);

has binary => (is => 'rw', default => sub{ {} });
has buildinfo => (is => 'rw');
has changes => (is => 'rw');
has source => (is => 'rw');
has udeb => (is => 'rw', default => sub{ {} });

has jobs => (is => 'rw', default => 1);
has processing_start => (is => 'rw', default => EMPTY);
has processing_end => (is => 'rw', default => EMPTY);

has cache => (is => 'rw', default => sub { {} });
has profile => (is => 'rw', default => sub { {} });

=item add_processable_from_file

=cut

sub add_processable_from_file {
    my ($self, $file) = @_;

    my $absolute = path($file)->realpath->stringify;
    croak "Cannot resolve $file: $!"
      unless $absolute;

    my $processable;

    if ($file =~ /\.dsc$/) {
        $processable = Lintian::Processable::Source->new;

    } elsif ($file =~ /\.buildinfo$/) {
        $processable = Lintian::Processable::Buildinfo->new;

    } elsif ($file =~ /\.d?deb$/) {
        # in ubuntu, automatic dbgsym packages end with .ddeb
        $processable = Lintian::Processable::Binary->new;

    } elsif ($file =~ /\.udeb$/) {
        $processable = Lintian::Processable::Udeb->new;

    } elsif ($file =~ /\.changes$/) {
        $processable = Lintian::Processable::Changes->new;

    } else {
        croak "$file is not a known type of package";
    }

    $processable->pooldir($self->pooldir);
    $processable->init($absolute);

    $self->add_processable($processable);

    return $processable;
}

=item process

Process group.

=cut

sub process {
    my ($self, $ignored_overrides, $option, $OUTPUT)= @_;

    $self->processing_start(gmtime->datetime . 'Z');

    my $groupname = $self->name;
    local $SIG{__WARN__} = sub { warn "Warning in group $groupname: $_[0]" };

    $OUTPUT->v_msg('Starting on group ' . $self->name);

    my @processables = $self->get_processables;
    for my $processable (@processables) {

        path($processable->basedir)->mkpath
          unless -e $processable->basedir;

        if ($processable->can('unpack')) {

            my $unpack_start = [gettimeofday];
            $OUTPUT->v_msg(
                'Unpacking packages in processable ' . $processable->name);

            $processable->unpack;

            my $unpack_raw_res = tv_interval($unpack_start);
            my $unpack_tres = sprintf('%.3fs', $unpack_raw_res);

            $OUTPUT->debug_msg(1,
                'Unpack of ' . $processable->name . " done ($unpack_tres)");
            $OUTPUT->perf_log(
                $self->name . ",total-processable-unpack,$unpack_raw_res");
        }
    }

    my $success = 1;

    my $timer = [gettimeofday];

    for my $processable ($self->get_processables){

        my $declared_overrides;

        $OUTPUT->debug_msg(1,
            'Base directory for processable: ' . $processable->basedir);

        unless ($option->{'no-override'}) {

            $OUTPUT->debug_msg(1, 'Loading overrides file (if any) ...');

            eval {$declared_overrides = $processable->overrides;};
            if (my $err = $@) {
                die $err if not ref $err or $err->errno != ENOENT;
            }

            my %alias = %{$self->profile->known_aliases};

            # treat renamed tags in overrides
            for my $tagname (keys %{$declared_overrides}) {

                # use new name if tag was renamed
                my $current = $alias{$tagname};

                next
                  unless defined $current;

                unless ($current eq $tagname) {

                    $processable->tag('renamed-tag',
                        "$tagname => $current in line "
                          .$declared_overrides->{$tagname}{$_}{line})
                      for keys %{$declared_overrides->{$tagname}};

                    $declared_overrides->{$current} //= {};
                    $declared_overrides->{$current}{$_}
                      = $declared_overrides->{$tagname}{$_}
                      for keys %{$declared_overrides->{$tagname}};

                    delete $declared_overrides->{$tagname};
                }
            }

            # complain about and filter out unknown tags in overrides
            my @unknown_overrides = grep { !$self->profile->get_taginfo($_) }
              keys %{$declared_overrides};
            for my $tagname (@unknown_overrides) {

                $processable->tag('malformed-override',
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

        # Filter out the "lintian" check if present - it does no real harm,
        # but it adds a bit of noise in the debug output.
        my @checknames
          = sort grep { $_ ne 'lintian' } $self->profile->enabled_checks;
        my @checkinfos = map { $self->profile->get_checkinfo($_) } @checknames;

        for my $checkinfo (@checkinfos) {
            my $checkname = $checkinfo->name;
            my $timer = [gettimeofday];

            # The lintian check is done by this frontend and we
            # also skip the check if it is not for this type of
            # package.
            next
              if !$checkinfo->is_check_type($processable->type);

            my $procid = $processable->identifier;
            $OUTPUT->debug_msg(1, "Running check: $checkname on $procid  ...");

            eval {$checkinfo->run_check($processable, $self);};
            my $err = $@;
            my $raw_res = tv_interval($timer);

            if ($err) {
                my $message = $err;
                $message
                  .= "warning: cannot run $checkname check on package $procid\n";
                $message .= "skipping check of $procid\n";
                warn $message;

                $success = 0;

                next;
            }

            my $tres = sprintf('%.3fs', $raw_res);
            $OUTPUT->debug_msg(1,
                "Check script $checkname for $procid done ($tres)");
            $OUTPUT->perf_log("$procid,check/$checkname,${raw_res}");
        }

        my $knownlc
          = List::Compare->new([map { $_->name } @{$processable->tags}],
            [$self->profile->known_tags]);
        my @unknown_tagnames = $knownlc->get_Lonly;
        croak 'tried to issue unknown tags: ' . join(SPACE, @unknown_tagnames)
          if @unknown_tagnames;

        # remove disabled tags
        my @enabled_tags
          = grep { $self->profile->tag_is_enabled($_->name) }
          @{$processable->tags};
        $processable->tags(\@enabled_tags);

        my %used_overrides;

        my @keep_tags;
        for my $tag (@{$processable->tags}) {

            next
              if $tag->name eq 'mismatched-override'
              || $tag->name eq 'unused-override';

            my $override;

            my $declared = $declared_overrides->{$tag->name};
            if ($declared) {

                # do not use EMPTY; hash keys literal
                # empty context in specification matches all
                $override = $declared->{''};

                # matches context exactly
                $override = $declared->{$tag->context}
                  unless $override;

                # look for patterns
                unless ($override) {
                    my @candidates
                      = sort grep { length $declared->{$_}{pattern} }
                      keys %{$declared};

                    my $match= firstval {
                        $tag->context =~ m/^$declared->{$_}{pattern}\z/
                    }
                    @candidates;

                    $override = $declared->{$match}
                      if $match;
                }

                # new hash keys are autovivified to 0
                $used_overrides{$tag->name}{$override->{context}}++
                  if $override;
            }

            $tag->override($override);

            push(@keep_tags, $tag);
        }

        $processable->tags(\@keep_tags);

        my %otherwise_visible = map { $_->name => 1 } @keep_tags;

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
            if ($otherwise_visible{$tagname}) {
                $processable->tag('mismatched-override', $tagname, $_)
                  for @unused_contexts;

            } else {
                $processable->tag('unused-override', $tagname, $_)
                  for @unused_contexts;
            }
        }

        # copy tag specifications into tags
        $_->info($self->profile->get_taginfo($_->name))
          for @{$processable->tags};
    }

    $self->processing_end(gmtime->datetime . 'Z');

    my $raw_res = tv_interval($timer);
    my $tres = sprintf('%.3fs', $raw_res);
    $OUTPUT->debug_msg(1,
        'Checking all of group ' . $self->name . " done ($tres)");
    $OUTPUT->perf_log($self->name . ",total-group-check,${raw_res}");

    if ($option->{'debug'} > 2) {

        # suppress warnings without reliable sizes
        $Devel::Size::warn = 0;

        my $pivot = ($self->get_processables)[0];
        my $group_id = $pivot->source . '/' . $pivot->source_version;
        my $group_usage
          = human_bytes(total_size([map { $_ } $self->get_processables]));
        $OUTPUT->debug_msg(3, "Memory usage [group:$group_id]: $group_usage");

        for my $processable ($self->get_processables) {
            my $id = $processable->identifier;
            my $usage = human_bytes(total_size($processable));
            $OUTPUT->debug_msg(3, "Memory usage [$id]: $usage");
        }
    }

    $self->clean_lab($OUTPUT);

    return $success;
}

=item clean_lab

Removes the lab files to conserve disk space. Global destruction will
also get these unless we are keeping the lab.

=cut

sub clean_lab {
    my ($self, $OUTPUT) = @_;

    my $total = [gettimeofday];

    for my $processable ($self->get_processables) {

        my $proc_id = $processable->identifier;
        $OUTPUT->debug_msg(1, "Auto removing: $proc_id ...");
        my $each = [gettimeofday];

        $processable->remove;

        my $raw_res = tv_interval($each);
        $OUTPUT->debug_msg(1, "Auto removing: $proc_id done (${raw_res}s)");
        $OUTPUT->perf_log("$proc_id,auto-remove entry,$raw_res");
    }

    my $raw_res = tv_interval($total);
    my $tres = sprintf('%.3fs', $raw_res);
    $OUTPUT->debug_msg(1,
        'Auto-removal all for group ' . $self->name . " done ($tres)");
    $OUTPUT->perf_log($self->name . ",total-group-auto-remove,$raw_res");

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

    if ($processable->tainted) {
        warn(
            sprintf(
                "warning: tainted %1\$s package '%2\$s', skipping\n",
                $processable->type, $processable->name
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

    croak 'Not a supported type (' . $processable->type . ')'
      unless exists $SUPPORTED_TYPES{$processable->type};

    if ($processable->type eq 'changes') {
        die 'Cannot add another ' . $processable->type . ' file'
          if $self->changes;
        $self->changes($processable);

    } elsif ($processable->type eq 'buildinfo') {
        # Ignore multiple .buildinfo files; use the first one
        $self->buildinfo($processable)
          unless $self->buildinfo;

    } elsif ($processable->type eq 'source'){
        die 'Cannot add another source package'
          if $self->source;
        $self->source($processable);

    } else {
        my $type = $processable->type;
        die 'Unknown type ' . $type
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
        die "Unknown type of processable: $type";
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
                  if $relation->implies($this->name);
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
                  if $relation->implies($that->name);
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

            my @names = ($processable->name, $processable->source);
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

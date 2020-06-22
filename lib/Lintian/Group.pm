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

use Carp;
use Cwd;
use Devel::Size qw(total_size);
use File::Spec;
use List::Compare;
use List::MoreUtils qw(uniq firstval);
use Path::Tiny;
use POSIX qw(ENOENT);
use Time::HiRes qw(gettimeofday tv_interval);
use Time::Piece;
use Unicode::UTF8 qw(valid_utf8 decode_utf8);

use Lintian::Deb822Parser qw(parse_dpkg_control_string);
use Lintian::Processable::Binary;
use Lintian::Processable::Buildinfo;
use Lintian::Processable::Changes;
use Lintian::Processable::Source;
use Lintian::Processable::Udeb;
use Lintian::Util qw(human_bytes);

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

=item C<saved_spelling_exceptions>

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

has saved_direct_dependencies => (is => 'rw', default => sub { {} });
has saved_direct_reliants => (is => 'rw', default => sub { {} });
has saved_spelling_exceptions => (is => 'rw', default => sub { {} });

=item Lintian::Group->init_from_file (FILE)

Add all processables from .changes or .buildinfo file FILE.

=cut

sub _get_processable {
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

    return $processable;
}

#  populates $self from a buildinfo or changes file.
sub init_from_file {
    my ($self, $path) = @_;

    return
      unless defined $path;

    my $processable = $self->_get_processable($path);
    return
      unless $processable;

    $self->add_processable($processable);

    my ($type) = $path =~ m/\.(buildinfo|changes)$/;
    return
      unless defined $type;

    my $bytes = path($path)->slurp;

    my $contents;
    if(valid_utf8($bytes)) {
        $contents = decode_utf8($bytes);
    } else {
        # try to proceed with nat'l encoding; stopping here breaks tests
        $contents = $bytes;
    }

    my @paragraphs;
    @paragraphs = parse_dpkg_control_string($contents)
      or die "$path is not a valid $type file";
    my $info = $paragraphs[0];

    my $dir = $path;
    if ($path =~ m,^/+[^/]++$,){
        # it is "/files.changes?"
        #  - In case you were wondering, we were told not to ask :)
        #   See #624149
        $dir = '/';
    } else {
        # it is "<something>/files.changes"
        $dir =~ s,(.+)/[^/]+$,$1,;
    }
    my $key = $type eq 'buildinfo' ? 'Checksums-Sha256' : 'Files';
    for my $line (split(/\n/, $info->{$key}//'')) {

        next
          unless defined $line;

        # trim both ends
        $line =~ s/^\s+|\s+$//g;

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

        die "$dir/$file does not exist, exiting\n"
          unless -f "$dir/$file";

        # only care about some files; ddeb is ubuntu dbgsym
        next
          unless $file =~ /\.(?:u|d)?deb$/
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
    my ($self, $OUTPUT)= @_;

    my $groupname = $self->name;
    local $SIG{__WARN__} = sub { warn "Warning in group $groupname: $_[0]" };

    my @processables = $self->get_processables;
    for my $processable (@processables) {

        $processable->create;

        # for sources pull in all related files so unpacked does not fail
        if ($processable->type eq 'source') {
            my (undef, $dir, undef)= File::Spec->splitpath($processable->path);
            for my $fs (split(/\n/, ($processable->field('Files') // EMPTY))) {

                # trim both ends
                $fs =~ s/^\s+|\s+$//g;

                next if $fs eq '';
                my @t = split(/\s+/, $fs);
                next if ($t[2] =~ m,/,);
                symlink("$dir/$t[2]", $processable->groupdir . "/$t[2]")
                  or croak("cannot symlink file $t[2]: $!");
            }
        }
    }

    $OUTPUT->v_msg('Unpacking packages in group ' . $self->name);

    my @unpack = grep { $_->can('unpack') } @processables;

    my $savedir = getcwd;
    $_->unpack for @unpack;
    chdir($savedir);

    return;
}

=item process

Process group.

=cut

sub process {
    my ($self, $ignored_overrides, $option, $OUTPUT)= @_;

    $self->processing_start(gmtime->datetime);

    my $success = 1;

    my $timer = [gettimeofday];

    my $groupname = $self->name;
    local $SIG{__WARN__} = sub { warn "Warning in group $groupname: $_[0]" };

    for my $processable ($self->get_processables){

        my $declared_overrides;
        my %used_overrides;

        $OUTPUT->debug_msg(1,
            'Base directory for group: ' . $processable->groupdir);

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
                        "$tagname => $current at line "
                          .$declared_overrides->{$tagname}{$_}{line})
                      for keys %{$declared_overrides->{$tagname}};

                    $declared_overrides->{$current} //= {};
                    $declared_overrides->{$current}{$_}
                      = $declared_overrides->{$tagname}{$_}
                      for keys %{$declared_overrides->{$tagname}};

                    delete $declared_overrides->{$tagname};
                }
            }

            # treat ignored overrides here
            for my $tagname (keys %{$declared_overrides}) {

                unless ($self->profile->is_overridable($tagname)) {
                    delete $declared_overrides->{$tagname};
                    $ignored_overrides->{$tagname}++;
                }
            }

            for my $tagname (keys %{$declared_overrides}) {

                my $contexts = $declared_overrides->{$tagname};

                # set the use count to zero for each context
                $used_overrides{$tagname}{$_} = 0 for keys %{$contexts};
            }
        }

        # Filter out the "lintian" check if present - it does no real harm,
        # but it adds a bit of noise in the debug output.
        my @checknames
          = grep { $_ ne 'lintian' } $self->profile->enabled_checks;
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
                print STDERR $err;
                print STDERR "internal error: cannot run $checkname check",
                  " on package $procid\n";
                $OUTPUT->warning("skipping check of $procid");
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

        my @keep_tags;
        for my $tag (@{$processable->tags}) {

            my $override;

            my $tag_overrides= $declared_overrides->{$tag->name};
            if ($tag_overrides) {

                # do not use EMPTY; hash keys literal
                # empty context in specification matches all
                $override = $tag_overrides->{''};

                # matches context exactly
                $override = $tag_overrides->{$tag->context}
                  unless $override;

                # look for patterns
                unless ($override) {
                    my @candidates
                      = sort grep { length $tag_overrides->{$_}{pattern} }
                      keys %{$tag_overrides};

                    my $match= firstval {
                        $tag->context =~ m/^$tag_overrides->{$_}{pattern}\z/
                    }
                    @candidates;

                    $override = $tag_overrides->{$match}
                      if $match;
                }

                $used_overrides{$tag->name}{$override->{context}}++
                  if $override;
            }

            $tag->override($override);

            push(@keep_tags, $tag);
        }

        $processable->tags(\@keep_tags);

        # look for unused overrides
        # should this not iterate over $tag_overrides instead?
        for my $tagname (keys %used_overrides) {

            next
              unless $self->profile->tag_is_enabled($tagname);

            my $tag_overrides = $used_overrides{$tagname};

            for my $context (keys %{$tag_overrides}) {

                next
                  if $tag_overrides->{$context};

                # cannot be overridden or suppressed
                $processable->tag('unused-override', $tagname, $context);
            }
        }

        # copy tag specifications into tags
        $_->info($self->profile->get_taginfo($_->name))
          for @{$processable->tags};
    }

    $self->processing_end(gmtime->datetime);

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

    my $dir = $self->_pool_path($processable);

    $processable->groupdir($dir);

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

# Given the package meta data (src_name, type, name, version, arch) return the
# path to it in the Lab.  The path returned will be absolute.
sub _pool_path {
    my ($self, $processable) = @_;

    my $dir = $self->pooldir;
    my $prefix;

    # If it is at least 4 characters and starts with "lib", use "libX"
    # as prefix
    if ($processable->source =~ m/^lib./) {
        $prefix = substr $processable->source, 0, 4;
    } else {
        $prefix = substr $processable->source, 0, 1;
    }

    my $path
      = $prefix
      . SLASH
      . $processable->source
      . SLASH
      . $processable->name
      . UNDERSCORE
      . $processable->version;
    $path .= UNDERSCORE . $processable->architecture
      unless $processable->type eq 'source';
    $path .= UNDERSCORE . $processable->type;

    # Turn spaces into dashes - spaces do appear in architectures
    # (i.e. for changes files).
    $path =~ s/\s/-/g;

    # Also replace ":" with "_" as : is usually used for path separator
    $path =~ s/:/_/g;

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

# sub direct_dependencies Needs-Info <>
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

# sub direct_reliants Needs-Info <>
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

# sub spelling_exceptions Needs-Info <>
sub spelling_exceptions {
    my ($self) = @_;

    return $self->saved_spelling_exceptions
      if keys %{$self->saved_spelling_exceptions};

    my %exceptions;

    foreach my $processable ($self->get_processables) {

        my @names = ($processable->name, $processable->source);
        push(@names, $processable->binaries)
          if $processable->type eq 'source';

        foreach my $name (@names) {
            $exceptions{$name} = 1;
            $exceptions{$_} = 1 for split m/-/, $name;
        }
    }

    $self->saved_spelling_exceptions(\%exceptions);

    return $self->saved_spelling_exceptions;
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

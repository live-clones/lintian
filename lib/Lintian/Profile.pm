# Copyright © 2011 Niels Thykier <niels@thykier.net>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
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

package Lintian::Profile;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use File::Find::Rule;
use List::Compare;
use List::MoreUtils qw(any none uniq first_value);
use Path::Tiny;

use Dpkg::Vendor qw(get_current_vendor get_vendor_info);

use Lintian::Check::Info;
use Lintian::Data;
use Lintian::Deb822::File;
use Lintian::Tag;

use constant EMPTY => q{};
use constant SPACE => q{ };

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Profile - Profile parser for Lintian

=head1 SYNOPSIS

 my $profile = Lintian::Profile->new ('debian');

=head1 DESCRIPTION

Lintian::Profile handles finding, parsing and implementation of
Lintian Profiles as well as loading the relevant Lintian checks.

=head1 INSTANCE METHODS

=over 4

=item $prof->known_aliases()

Returns a hash with old names that have new names.

=item $prof->profile_list

Returns a list ref of the (normalized) names of the profile and its
parents.  The last element of the list is the name of the profile
itself, the second last is its parent and so on.

Note: This list reference and its contents should not be modified.

=item $prof->name

Returns the name of the profile, which may differ from the name used
to create this instance of the profile (e.g. due to symlinks).

=cut

has known_aliases => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has known_checks_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has check_tagnames => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has display_level_lookup => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub {
        {
            classification => 0,
            pedantic       => 0,
            info           => 0,
            warning        => 1,
            error          => 1,
        }
    });

has enabled_checks_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has enabled_tags_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has files => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has known_tags_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has name => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // EMPTY;},
    default => EMPTY
);

has non_overridable_tags => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has parent_map => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has profile_list => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has saved_include_path => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has saved_safe_include_path => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has known_vendors => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub {

        my $vendor = Dpkg::Vendor::get_current_vendor();
        croak 'Could not determine the current vendor'
          unless $vendor;

        my @vendors;
        push(@vendors, lc $vendor);

        while ($vendor) {
            my $info = Dpkg::Vendor::get_vendor_info($vendor);
            # Cannot happen atm, but in case Dpkg::Vendor changes its internals
            #  or our code changes
            croak "Could not look up the parent vendor of $vendor"
              unless $info;

            $vendor = $info->{'Parent'};
            push(@vendors, lc $vendor)
              if $vendor;
        }

        return \@vendors;
    });

=item load ([$profname[, $ipath[, $extra]]])

Loads a new profile.  $profname is the name of the profile and $ipath
is a list reference containing the path to one (or more) Lintian
"roots".

If $profname is C<undef>, the default vendor will be loaded based on
Dpkg::Vendor::get_current_vendor.

If $ipath is not given, a default one will be used.

=cut

sub load {
    my ($self, $name, $include_path, $extra) = @_;

    my @full_inc_path;

    unless (defined $include_path) {
        # Temporary fix (see _safe_include_path)
        push(@full_inc_path, "$ENV{'HOME'}/.lintian")
          if length $ENV{'HOME'};

        push(@full_inc_path, '/etc/lintian');

        # ENV{LINTIAN_BASE} replaces /usr/share/lintian if present.
        $include_path = [$ENV{LINTIAN_BASE} // '/usr/share/lintian'];

        push(@full_inc_path, @{$include_path});
    }

    push(@full_inc_path, @{ $extra->{'restricted-search-dirs'} // [] })
      if defined $extra;

    push(@full_inc_path, @{$include_path});

    $self->saved_include_path(\@full_inc_path);
    $self->saved_safe_include_path($include_path);

    Lintian::Data->set_vendor($self);

    for my $tagdir ($self->_safe_include_path('tags')) {

        next
          unless -d $tagdir;

        my @tagpaths
          = File::Find::Rule->file->name(qw(*.tag *.desc))->in($tagdir);
        for my $tagpath (@tagpaths) {

            my $tag = Lintian::Tag->new;
            $tag->load($tagpath);

            die "Tag in $tagpath is not associated with a check"
              unless length $tag->check;

            next
              if exists $self->known_tags_by_name->{$tag->name};

            $self->known_tags_by_name->{$tag->name} = $tag;
            $self->check_tagnames->{$tag->check} //= [];
            push(@{$self->check_tagnames->{$tag->check}},$tag->name);
        }
    }

    for my $checkdir ($self->_safe_include_path('checks')) {

        next
          unless -d $checkdir;

        my @checkpaths= File::Find::Rule->file->name('*.pm')->in($checkdir);

        for my $checkpath (@checkpaths) {
            my $relative = path($checkpath)->relative($checkdir)->stringify;
            my ($name) = ($relative =~ qr/^(.*)\.pm$/);

            # ignore duplicates
            next
              if exists $self->known_checks_by_name->{$name};

            my $check = Lintian::Check::Info->new;
            $check->basedir($checkdir);
            $check->name($name);
            $check->load;

            $self->known_checks_by_name->{$name} = $check;
        }
    }

    # add internal 'lintian' check to allow issuance of such tags
    my $lintian = Lintian::Check::Info->new;
    $lintian->name('lintian');
    $self->known_checks_by_name->{lintian} = $lintian;

    $self->read_profile($name);

    # record known aliases
    for my $tag (values %{ $self->known_tags_by_name }) {

        my @taken
          = grep { defined $self->known_aliases->{$_} }@{$tag->renamed_from};

        die 'These aliases of the tag '
          . $tag->name
          . ' are taken already: '
          . join(SPACE, @taken)
          if @taken;

        $self->known_aliases->{$_} = $tag->name for @{$tag->renamed_from};
    }

    return;
}

=item $prof->known_tags

=cut

sub known_tags {
    my ($self) = @_;

    return keys %{ $self->known_tags_by_name };
}

=item $prof->enabled_tags

=cut

sub enabled_tags {
    my ($self) = @_;

    return keys %{ $self->enabled_tags_by_name };
}

=item $prof->get_tag ($name)

Returns the Lintian::Tag for $tag if known.
Otherwise it returns undef.

=cut

sub get_tag {
    my ($self, $name) = @_;

    return $self->known_tags_by_name->{$name};
}

=item $prof->is_overridable ($tag)

Returns a false value if the tag has been marked as
"non-overridable".  Otherwise it returns a truth value.

=cut

sub is_overridable {
    my ($self, $tagname) = @_;

    return !exists $self->non_overridable_tags->{$tagname};
}

=item $prof->known_checks

=cut

sub known_checks {
    my ($self) = @_;

    return keys %{ $self->known_checks_by_name };
}

=item $prof->enabled_checks

=cut

sub enabled_checks {
    my ($self) = @_;

    return keys %{ $self->enabled_checks_by_name };
}

=item $prof->get_checkinfo ($name)

Returns the Lintian::Check::Info for $name.
Otherwise it returns undef.

=cut

sub get_checkinfo {
    my ($self, $name) = @_;

    return $self->known_checks_by_name->{$name};
}

=item $prof->enable_tag ($name)

Enables a tag.

=cut

sub enable_tag {
    my ($self, $name) = @_;

    my $tag = $self->known_tags_by_name->{$name};
    die "Unknown tag $name"
      unless $tag;

    $self->enabled_checks_by_name->{$tag->check}++
      unless exists $self->enabled_tags_by_name->{$name};

    $self->enabled_tags_by_name->{$name} = 1;

    return;
}

=item $prof->disable_tag ($name)

Disable a tag.

=cut

sub disable_tag {
    my ($self, $name) = @_;

    my $tag = $self->known_tags_by_name->{$name};
    die "Unknown tag $name"
      unless $tag;

    delete $self->enabled_checks_by_name->{$tag->check}
      unless exists $self->enabled_tags_by_name->{$name}
      && --$self->enabled_checks_by_name->{$tag->check};

    delete $self->enabled_tags_by_name->{$name};

    return;
}

=item $prof->include_path ([$path])

Returns an array of paths to the (partial) Lintian roots, which are
used by this profile.  The paths are ordered from "highest" to
"lowest" priority (i.e. items in the earlier paths should shadow those
in later ones).

If $path is given, the array will contain the paths to the path in
these roots denoted by $path.

Paths returned are not guaranteed to exists.

=cut

sub include_path {
    my ($self, $path) = @_;

    return map { "$_/$path" } @{ $self->saved_include_path }
      if defined $path;

    return @{ $self->saved_include_path };
}

# Temporary until aptdaemon (etc.) has been upgraded to handle
# Lintian loading code from user dirs.
# LP: #1162947
sub _safe_include_path {
    my ($self, $path) = @_;

    return map { "$_/$path" } @{ $self->saved_safe_include_path }
      if defined $path;

    return @{ $self->saved_safe_include_path };
}

=item read_profile

=cut

sub read_profile {
    my ($self, $requested_name) = @_;

    my @search_space;

    if (!defined $requested_name) {
        @search_space = map { "$_/main" } @{$self->known_vendors};

    } elsif ($requested_name !~ m{/}) {
        @search_space = ("$requested_name/main");

    } elsif ($requested_name =~ m{^[^.]+/[^/.]+$}) {
        @search_space = ($requested_name);

    } else {
        croak "$requested_name is not a valid profile name";
    }

    my @candidates;
    for my $include_path ($self->include_path('profiles')) {
        push(@candidates, map { "$include_path/$_.profile" } @search_space);
    }

    my $path = first_value { -e } @candidates;

    croak 'Could not find a profile matching: ' . join(SPACE, @search_space)
      unless length $path;

    my $deb822 = Lintian::Deb822::File->new;
    my @paragraphs = $deb822->read_file($path);

    my ($header, @sections) = @paragraphs;

    croak "Profile has no header in $path"
      unless defined $header;

    my $name = $header->unfolded_value('Profile');
    croak "Profile has no name in $path"
      unless length $name;

    croak "Invalid Profile field in $path"
      if $name =~ m{^/} || $name =~ m{\.};

    # normalize name
    $name .= '/main'
      unless $name =~ m{/};

    croak "Recursive definition of $name"
      if exists $self->parent_map->{$name};

    # Mark as being loaded.
    $self->parent_map->{$name} = 0;

    $self->name($name)
      unless length $self->name;

    $self->read_profile($header->unfolded_value('Extends'))
      if $header->exists('Extends');

    # Add the profile to the "chain" after loading its parent (if
    # any).
    push(@{$self->profile_list}, $name);

    my @valid_fields
      = qw(Profile Extends Enable-Tags-From-Check Disable-Tags-From-Check Enable-Tags Disable-Tags);
    my @unknown_fields = $header->extra(@valid_fields);
    croak "Unknown fields in header of profile $name: "
      . join(SPACE, @unknown_fields)
      if @unknown_fields;

    my @enable_checks
      = $header->trimmed_list('Enable-Tags-From-Check', qr/\s*,\s*/);
    my @disable_checks
      = $header->trimmed_list('Disable-Tags-From-Check', qr/\s*,\s*/);

    # List::MoreUtils has 'duplicates' starting at 0.423
    my @allchecks = (@enable_checks, @disable_checks);
    my %count;
    $count{$_}++ for @allchecks;
    my @duplicate_checks = grep { $count{$_} > 1 } keys %count;
    die "These checks appear in profile $name more than once: "
      . join(SPACE, @duplicate_checks)
      if @duplicate_checks;

    # make sure checks are loaded
    my @needed_checks
      = grep { !exists $self->known_checks_by_name->{$_} } @allchecks;

    for my $name (@needed_checks) {
        my $location;
        for my $directory ($self->_safe_include_path('checks')) {

            if (-f "$directory/$name.desc") {
                $location = $directory;
                last;
            }
        }

        croak "Profile $name references unknown check $name"
          unless defined $location;

        # ignore duplicates
        next
          if exists $self->known_checks_by_name->{$name};

        my $info = Lintian::Check::Info->new;
        $info->basedir($location);
        $info->name($name);
        $info->load;

        $self->known_checks_by_name->{$name} = $info;
    }

    # associate tags with checks
    for my $check (values %{ $self->known_checks_by_name }) {

        $self->check_tagnames->{$check->name} //= [];
        my @tagnames = @{$self->check_tagnames->{$check->name}};
        my @tags = map { $self->known_tags_by_name->{$_} } @tagnames;

        $_->check_type($check->type) for @tags;

        $check->add_tag($_) for @tags;
    }

    my @enable_tags = $header->trimmed_list('Enable-Tags', qr/\s*,\s*/);
    my @disable_tags = $header->trimmed_list('Disable-Tags', qr/\s*,\s*/);

    # List::MoreUtils has 'duplicates' starting at 0.423
    my @alltags = (@enable_tags, @disable_tags);
    %count = ();
    $count{$_}++ for @alltags;
    my @duplicate_tags = grep { $count{$_} > 1 } keys %count;
    die "These tags appear in in profile $name more than once: "
      . join(SPACE, @duplicate_tags)
      if @duplicate_tags;

    push(@enable_tags, $self->known_checks_by_name->{$_}->tags)
      for @enable_checks;

    push(@disable_tags, $self->known_checks_by_name->{$_}->tags)
      for @disable_checks;

    my @unknown_tags = grep { !exists $self->known_tags_by_name->{$_} }
      uniq(@enable_tags, @disable_tags);

    croak "Unknown tags in profile $name: " . join(SPACE, @unknown_tags)
      if @unknown_tags;

    $self->enable_tag($_) for @enable_tags;
    $self->disable_tag($_) for @disable_tags;

    # section counter
    my $position = 2;

    for my $section (@sections){

        my @valid_fields = qw(Tags Overridable Severity);
        my @unknown_fields = $section->extra(@valid_fields);
        croak "Unknown fields in section $position of profile $name: "
          . join(SPACE, @unknown_fields)
          if @unknown_fields;

        my @tags = $section->trimmed_list('Tags', qr/\s*,\s*/);
        croak
          "Tags field missing or empty in section $position of profile $name"
          unless @tags;

        my $severity = $section->unfolded_value('Severity');
        croak
"Profile $name contains invalid severity $severity in section $position"
          if length $severity && none { $severity eq $_ }
        @Lintian::Tag::SEVERITIES;

        my $overridable
          = $self->_parse_boolean($section->unfolded_value('Overridable'),
            -1, $name,$position);

        for my $tagname (@tags) {

            my $tag = $self->known_tags_by_name->{$tagname};
            croak "Unknown tag $tagname in $name (section $position)"
              unless defined $tag;

            croak
"Classification tag $tagname cannot take a severity (profile $name, section $position"
              if $tag->visibility eq 'classification';

            $tag->effective_severity($severity)
              if length $severity;

            if ($overridable != -1) {
                if ($overridable) {
                    delete $self->non_overridable_tags->{$tagname};
                } else {
                    $self->non_overridable_tags->{$tagname} = 1;
                }
            }
        }

    } continue {
        $position++;
    }

    return;
}

# $self->_parse_boolean($text, $default, $profile, $position);
#
# Parse $text as a string representing a bool; if undefined return $default.
# $profile and $position are the Profile name and section number - used for
# error reporting.
sub _parse_boolean {
    my ($self, $text, $default, $profile, $position) = @_;

    return $default
      unless defined $text;

    return $text == 0 ? 0 : 1
      if $text =~ /^-?\d+$/;

    $text = lc $text;

    return 1
      if $text eq 'true' or $text =~ /^y(?:es)?$/;

    return 0
      if $text eq 'false' or $text =~ /^no?$/;

    croak "$text is not a boolean value in $profile (section $position)";
}

=item display_level_for_tag

=cut

sub display_level_for_tag {
    my ($self, $tagname) = @_;

    my $tag = $self->get_tag($tagname);
    croak "Unknown tag $tagname"
      unless defined $tag;

    return $self->display_level_lookup->{$tag->effective_severity};
}

=item tag_is_enabled(TAG)

=cut

sub tag_is_enabled {
    my ($self, $tagname) = @_;

    return 1
      if exists $self->enabled_tags_by_name->{$tagname};

    return 0;
}

=item display(OPERATION, RELATION, SEVERITY)

Configure which tags are displayed by severity.  OPERATION
is C<+> to display the indicated tags, C<-> to not display the indicated
tags, or C<=> to not display any tags except the indicated ones.  RELATION
is one of C<< < >>, C<< <= >>, C<=>, C<< >= >>, or C<< > >>.  The
OPERATION will be applied to all values of severity that
match the given RELATION on the SEVERITY argument.  If
either of those arguments are undefined, the action applies to any value
for that variable.  For example:

    $tags->display('=', '>=', 'error');

turns off display of all tags and then enables display of any tag of
severity error or higher.

    $tags->display('+', '>', 'warning');

adds to the current configuration display of all tags with a severity
higher than warning.

    $tags->display('-', '=', 'info');

turns off display of tags of severity info.

This method throws an exception on errors, such as an unknown severity or
an impossible constraint (like C<< > serious >>).

=cut

# Generate a subset of a list given the element and the relation.  This
# function makes a hard assumption that $rel will be one of <, <=, =, >=,
# or >.  It is not syntax-checked.
sub _relation_subset {
    my ($self, $element, $rel, @list) = @_;

    if ($rel eq '=') {
        return grep { $_ eq $element } @list;
    }

    if (substr($rel, 0, 1) eq '<') {
        @list = reverse @list;
    }

    my $found;
    for my $i (0..$#list) {
        if ($element eq $list[$i]) {
            $found = $i;
            last;
        }
    }

    return
      unless defined($found);

    if (length($rel) > 1) {
        return @list[$found .. $#list];

    }

    return
      if $found == $#list;

    return @list[($found + 1) .. $#list];
}

# Given the operation, relation, and severity, produce a
# human-readable representation of the display level string for errors.
sub _format_level {
    my ($self, $op, $rel, $severity) = @_;

    if (not defined $severity) {
        return "$op $rel";
    } else {
        return "$op $rel $severity (severity)";
    }
}

sub display {
    my ($self, $op, $rel, $severity) = @_;

    unless ($op =~ /^[+=-]\z/ and $rel =~ /^(?:[<>]=?|=)\z/) {
        my $error = $self->_format_level($op, $rel, $severity);
        die 'invalid display constraint ' . $error;
    }

    if ($op eq '=') {
        for my $s (@Lintian::Tag::SEVERITIES) {
            $self->display_level_lookup->{$s} = 0;
        }
    }

    my $status = ($op eq '-' ? 0 : 1);

    my @severities;
    if ($severity) {
        @severities
          = $self->_relation_subset($severity, $rel,@Lintian::Tag::SEVERITIES);
    } else {
        @severities = @Lintian::Tag::SEVERITIES;
    }

    unless (@severities) {
        my $error = $self->_format_level($op, $rel, $severity);
        die 'invalid display constraint ' . $error;
    }

    for my $s (@severities) {
        $self->display_level_lookup->{$s} = $status;
    }

    return;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

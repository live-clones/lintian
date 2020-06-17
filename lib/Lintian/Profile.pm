# Copyright © 2011 Niels Thykier <niels@thykier.net>
# Copyright © 2020 Felix Lechner <felix.lechner@lease-up.com>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
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
use List::MoreUtils qw(any none uniq);
use Path::Tiny;

use Dpkg::Vendor qw(get_current_vendor get_vendor_info);

use Lintian::Check::Info;
use Lintian::Deb822Parser qw(read_dpkg_control);
use Lintian::Tag::Info;

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

has vendor_cache => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

=item load ([$profname[, $ipath[, $extra]]])

Loads a new profile.  $profname is the name of the profile and $ipath
is a list reference containing the path to one (or more) Lintian
"roots".

If $profname is C<undef>, the default vendor will be loaded based on
Dpkg::Vendor::get_current_vendor.

If $ipath is not given, a default one will be used.

=cut

sub load {
    my ($self, $name, $ipath, $extra) = @_;

    my ($profile, @full_inc_path);

    if (!defined $ipath) {
        # Temporary fix (see _safe_include_path)
        @full_inc_path = (_default_inc_path());
        if (defined $ENV{'LINTIAN_ROOT'}) {
            $ipath = [$ENV{'LINTIAN_ROOT'}];
        } else {
            $ipath = ['/usr/share/lintian'];
        }
    }

    if (defined $extra) {
        if (exists($extra->{'restricted-search-dirs'})) {
            @full_inc_path = @{ $extra->{'restricted-search-dirs'} };
        }
    }
    push @full_inc_path, @$ipath;

    $self->saved_include_path(\@full_inc_path);
    $self->saved_safe_include_path($ipath);

    if (defined $name) {
        croak "Illegal profile name $name"
          if $name =~ m{^/}
          || $name =~ m{\.};
        ($profile, undef) = $self->_find_vendor_profile($name);
    } else {
        ($profile, $name) = $self->_find_vendor_profile;
    }

    croak "Cannot find profile $name (in "
      . join(', ', map { "$_/profiles" } @$ipath).')'
      unless $profile;

    # populate known tags and their check associations
    for my $tagroot ($self->_safe_include_path('tags')) {

        next
          unless -d $tagroot;

        my @descfiles = File::Find::Rule->file()->name('*.desc')->in($tagroot);
        for my $tagpath (@descfiles) {

            my $taginfo = Lintian::Tag::Info->new;
            $taginfo->load($tagpath);

            die "Tag in $tagpath is not associated with a check"
              unless length $taginfo->check;

            unless (exists $self->known_tags_by_name->{$taginfo->name}) {
                $self->known_tags_by_name->{$taginfo->name} = $taginfo;
                push(
                    @{$self->check_tagnames->{$taginfo->check}},
                    $taginfo->name
                );
            }
        }
    }

    my @checkdirs = grep { -d $_ } $self->_safe_include_path('checks');

    for my $checkdir (@checkdirs) {

        my @descpaths= File::Find::Rule->file->name('*.pm')->in($checkdir);

        for my $desc (@descpaths) {
            my $relative = path($desc)->relative($checkdir)->stringify;
            my ($name) = ($relative =~ qr/^(.*)\.pm$/);
            # _parse_check ignores duplicates on its own
            $self->_parse_check($name, $checkdir);
        }
    }

    # load internal 'lintian' check to allow issuance of such tags
    my $lintian = Lintian::Check::Info->new;
    $lintian->name('lintian');
    $self->known_checks_by_name->{lintian} = $lintian;

    $self->_read_profile($profile);

    # record known aliases
    for my $taginfo (values %{ $self->known_tags_by_name }) {

        my @taken
          = grep { defined $self->known_aliases->{$_} } $taginfo->aliases;
        die 'These aliases of the tag '
          . $taginfo->name
          . ' are taken already: '
          . join(SPACE, @taken)
          if @taken;

        $self->known_aliases->{$_} = $taginfo->name for $taginfo->aliases;
    }

    return $self;
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

=item $prof->get_taginfo ($name)

Returns the Lintian::Tag::Info for $tag if known.
Otherwise it returns undef.

=cut

sub get_taginfo {
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

    my $taginfo = $self->known_tags_by_name->{$name};
    die "Unknown tag $name"
      unless $taginfo;

    $self->enabled_checks_by_name->{$taginfo->check}++
      unless exists $self->enabled_tags_by_name->{$name};

    $self->enabled_tags_by_name->{$name} = 1;

    return;
}

=item $prof->disable_tag ($name)

Disable a tag.

=cut

sub disable_tag {
    my ($self, $name) = @_;

    my $taginfo = $self->known_tags_by_name->{$name};
    die "Unknown tag $name"
      unless $taginfo;

    delete $self->enabled_checks_by_name->{$taginfo->check}
      unless exists $self->enabled_tags_by_name->{$name}
      && --$self->enabled_checks_by_name->{$taginfo->check};

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

# $prof->_find_profile ($name)
#
# Finds a profile called $name in the search directories and returns
# the path to it.  If $name does not contain a slash, then it will look
# for a profile called "$name/main" instead of $name.
#
# Returns a non-truth value if the profile could not be found.  $name
# cannot contain any dots.

sub _find_profile {
    my ($self, $name) = @_;

    croak "$name is not a valid profile name"
      if $name =~ m{\.};

    # $vendor is short for $vendor/main
    $name = "$name/main"
      unless $name =~ m{/};

    my $filename = "$name.profile";
    foreach my $path ($self->include_path('profiles')) {
        return "$path/$filename"
          if -e "$path/$filename";
    }

    return EMPTY;
}

# $self->_read_profile($path)
#
# Parses the profile stored in the file $path; if this method returns
# normally, the profile will have been parsed successfully.
sub _read_profile {
    my ($self, $path) = @_;

    my @paragraphs = read_dpkg_control($path, 0);

    for my $paragraph (@paragraphs) {

        # unwrap continuation lines
        $paragraph->{$_} =~ s/\n/ /g for keys %{$paragraph};

        # trim both ends
        $paragraph->{$_} =~ s/^\s+|\s+$//g for keys %{$paragraph};

        # reduce multiple spaces to one
        $paragraph->{$_} =~ s/\s+/ /g for keys %{$paragraph};
    }

    my ($header, @sections) = @paragraphs;

    croak "Profile has no header in $path"
      unless defined $header;

    my $name = $header->{Profile};
    croak "Profile has no name in $path"
      unless length $name;

    croak "Invalid Profile field in $path"
      if $name =~ m{^/} || $name =~ m{\.};

    # normalize name
    $name .= '/main'
      unless $name =~ m{/};

    croak "Recursive definition of $name"
      if exists $self->parent_map->{$name};

    $self->parent_map->{$name} = 0; # Mark as being loaded.

    $self->name($name)
      unless length $self->name;

    my $parentname = $header->{Extends};
    if (length $parentname){
        croak "Invalid Extends field in $path"
          if $parentname =~ m{\.};

        my ($parentpath, undef) = $self->_find_vendor_profile($parentname);
        croak "Cannot find $parentname, which $name extends"
          unless $parentpath;

        $self->_read_profile($parentpath);
    }

    # Add the profile to the "chain" after loading its parent (if
    # any).
    push(@{$self->profile_list}, $name);

    $self->_read_profile_tags($name, $header);

    my $i = 2; # section counter
    foreach my $psection (@sections){
        $self->_read_profile_section($name, $psection, $i++);
    }

    return;
}

# $self->_read_profile_section($profile, $paragraph, $section)
#
# Parses and applies the effects of $paragraph (a paragraph
# in the profile). $profile is the name of the profile and
# $no is section number (both of these are only used for
# error reporting).
sub _read_profile_section {
    my ($self, $profile, $paragraph, $section) = @_;

    my @valid_fields = qw(Tags Overridable Severity);
    my $validlc = List::Compare->new([keys %{$paragraph}], \@valid_fields);
    my @unknown_fields = uniq $validlc->get_Lonly;
    croak "Unknown fields in section $section of profile $profile: "
      . join(SPACE, @unknown_fields)
      if @unknown_fields;

    my @tags = split(/\s*,\s*/, $paragraph->{'Tags'} // EMPTY);
    croak "Tags field missing or empty in section $section of profile $profile"
      unless @tags;

    my $severity = $paragraph->{'Severity'} // EMPTY;
    croak
"Profile $profile contains invalid severity $severity in section $section"
      if length $severity && none { $severity eq $_ }
    @Lintian::Tag::Info::SEVERITIES;

    my $overridable
      = $self->_parse_boolean($paragraph->{'Overridable'},-1, $profile,
        $section);

    foreach my $tag (@tags) {

        my $taginfo = $self->known_tags_by_name->{$tag};
        croak "Unknown check $tag in $profile (section $section)"
          unless defined $taginfo;

        croak
"Classification tag $tag cannot take a severity (profile $profile, section $section"
          if $taginfo->original_severity eq 'classification';

        $taginfo->effective_severity($severity)
          if length $severity;

        if ($overridable != -1) {
            if ($overridable) {
                delete $self->non_overridable_tags->{$tag};
            } else {
                $self->non_overridable_tags->{$tag} = 1;
            }
        }
    }

    return;
}

# $self->_read_profile_tags($profile, $header)
#
# Interprets the {dis,en}able-tags{,-from-check} fields from
# the profile header $header.  $profile is the name of the
# profile (used for error reporting).
#
# If it returns, the enabled tags will be updated to reflect
#  the tags enabled/disabled by this profile (but not its
#  parents).
sub _read_profile_tags{
    my ($self, $profile, $header) = @_;

    my @valid_fields
      = qw(Profile Extends Enable-Tags-From-Check Disable-Tags-From-Check Enable-Tags Disable-Tags);
    my $validlc = List::Compare->new([keys %{$header}], \@valid_fields);
    my @unknown_fields = uniq $validlc->get_Lonly;
    croak "Unknown fields in header of profile $profile: "
      . join(SPACE, @unknown_fields)
      if @unknown_fields;

    my @enable_checks
      = split(/\s*,\s*/, $header->{'Enable-Tags-From-Check'} // EMPTY);
    my @disable_checks
      = split(/\s*,\s*/, $header->{'Disable-Tags-From-Check'} // EMPTY);

    # List::MoreUtils has 'duplicates' starting at 0.423
    my @allchecks = (@enable_checks, @disable_checks);
    my %count;
    $count{$_}++ for @allchecks;
    my @duplicate_checks = grep { $count{$_} > 1 } keys %count;
    die "These checks appear in profile $profile more than once: "
      . join(SPACE, @duplicate_checks)
      if @duplicate_checks;

    # make sure checks are loaded
    my @needed_checks
      = grep { !exists $self->known_checks_by_name->{$_} } @allchecks;

    for my $check (@needed_checks) {
        my $location;
        for my $directory ($self->_safe_include_path('checks')) {

            if (-f "$directory/$check.desc") {
                $location = $directory;
                last;
            }
        }

        croak "Profile $profile references unknown check $check"
          unless defined $location;

        my $check = $self->_parse_check($check, $location);
    }

    # associate tags with checks
    for my $check (values %{ $self->known_checks_by_name }) {
        my @tagnames = @{$self->check_tagnames->{$check->name}};
        my @taginfos = map { $self->known_tags_by_name->{$_} } @tagnames;

        $_->check_type($check->type) for @taginfos;

        $check->add_taginfo($_) for @taginfos;
    }

    my @enable_tags= split(/\s*,\s*/, $header->{'Enable-Tags'} // EMPTY);
    my @disable_tags= split(/\s*,\s*/, $header->{'Disable-Tags'} // EMPTY);

    # List::MoreUtils has 'duplicates' starting at 0.423
    my @alltags = (@enable_tags, @disable_tags);
    %count = ();
    $count{$_}++ for @alltags;
    my @duplicate_tags = grep { $count{$_} > 1 } keys %count;
    die "These tags appear in in profile $profile more than once: "
      . join(SPACE, @duplicate_tags)
      if @duplicate_tags;

    push(@enable_tags, $self->known_checks_by_name->{$_}->tags)
      for @enable_checks;

    push(@disable_tags, $self->known_checks_by_name->{$_}->tags)
      for @disable_checks;

    my @unknown_tags = grep { !exists $self->known_tags_by_name->{$_} }
      uniq(@enable_tags, @disable_tags);

    croak "Unknown tags in profile $profile: " . join(SPACE, @unknown_tags)
      if @unknown_tags;

    $self->enable_tag($_) for @enable_tags;
    $self->disable_tag($_) for @disable_tags;

    return;
}

# $self->_parse_boolean($text, $default, $profile, $section);
#
# Parse $text as a string representing a bool; if undefined return $default.
# $profile and $section are the Profile name and section number - used for
# error reporting.
sub _parse_boolean {
    my ($self, $text, $default, $profile, $section) = @_;

    return $default
      unless defined $text;

    return $text == 0 ? 0 : 1
      if $text =~ /^-?\d+$/;

    $text = lc $text;

    return 1
      if $text eq 'true' or $text =~ /^y(?:es)?$/;

    return 0
      if $text eq 'false' or $text =~ /^no?$/;

    croak "$text is not a boolean value in $profile (section $section)";
}

sub _parse_check {
    my ($self, $name, $directory) = @_;

    return $self->known_checks_by_name->{$name}
      if exists $self->known_checks_by_name->{$name};

    my $check = Lintian::Check::Info->new;
    $check->basedir($directory);
    $check->name($name);
    $check->load;

    $self->known_checks_by_name->{$name} = $check;

    # needed for checks without tags
    $self->check_tagnames->{$name} //= [];

    return $check;
}

sub _default_inc_path {
    my @path;

    push @path, "$ENV{'HOME'}/.lintian"
      if defined $ENV{'HOME'};

    push @path, '/etc/lintian';

    # ENV{LINTIAN_ROOT} replaces /usr/share/lintian if present.
    push @path, $ENV{'LINTIAN_ROOT'}
      if defined $ENV{'LINTIAN_ROOT'};

    push @path, '/usr/share/lintian'
      unless defined $ENV{'LINTIAN_ROOT'};

    return @path;
}

sub _find_vendor_profile {
    my ($self, $prof) = @_;
    my @vendors;

    if (defined $prof and $prof !~ m/[{}]/) {
        # no substitution required...
        return ($self->_find_profile($prof), $prof);

    } elsif (defined $prof) {
        my $cpy = $prof;
        # Check for unknown (or broken) subst.
        $cpy =~ s/\Q{VENDOR}\E//g;
        croak "Unknown substitution \"$1\" (in \"$prof\")"
          if $cpy =~ m/\{([^ \}]+)\}/;
        croak "Bad, broken or empty substitution marker in \"$prof\""
          if $cpy =~ m/[{}]/;
    }

    $prof //= '{VENDOR}/main';

    @vendors = @{ $self->vendor_cache };
    unless (@vendors) {

        my $vendor = Dpkg::Vendor::get_current_vendor();
        croak 'Could not determine the current vendor'
          unless $vendor;

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

        $self->vendor_cache(\@vendors);
    }

    foreach my $vendor (@vendors) {

        my $profname = $prof;
        $profname =~ s/\Q{VENDOR}\E/$vendor/g;

        my $file = $self->_find_profile($profname);

        return ($file, $profname)
          if $file;
    }

    croak "Could not find a profile matching $prof for vendor $vendors[0]";
}

=item display_level_for_tag

=cut

sub display_level_for_tag {
    my ($self, $tag) = @_;

    my $taginfo = $self->get_taginfo($tag);
    croak "Unknown tag $tag"
      unless defined $taginfo;

    return $self->display_level_lookup->{$taginfo->effective_severity};
}

=item tag_is_enabled(TAG)

=cut

sub tag_is_enabled {
    my ($self, $tag) = @_;

    return 1
      if exists $self->enabled_tags_by_name->{$tag};

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
        for my $s (@Lintian::Tag::Info::SEVERITIES) {
            $self->display_level_lookup->{$s} = 0;
        }
    }

    my $status = ($op eq '-' ? 0 : 1);

    my @severities;
    if ($severity) {
        @severities = $self->_relation_subset($severity, $rel,
            @Lintian::Tag::Info::SEVERITIES);
    } else {
        @severities = @Lintian::Tag::Info::SEVERITIES;
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

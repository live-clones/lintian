# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
# Copyright (C) 2018 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Profile;

use v5.20;
use warnings;
use utf8;

use Carp qw(carp croak);
use Const::Fast;
use Cwd qw(realpath);
use File::BaseDir qw(config_home config_files data_home);
use File::Find::Rule;
use List::Compare;
use List::SomeUtils qw(any none uniq first_value);
use Path::Tiny;
use POSIX qw(ENOENT);
use Unicode::UTF8 qw(encode_utf8);

use Dpkg::Vendor qw(get_current_vendor get_vendor_info);

use Lintian::Data;
use Lintian::Deb822;
use Lintian::Tag;
use Lintian::Util qw(match_glob);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $HYPHEN => q{-};
const my $EQUAL => q{=};

const my $FIELD_SEPARATOR => qr/ \s+ | \s* , \s* /sx;

const my @VALID_HEADER_FIELDS => qw(
  Profile
  Extends
  Enable-Tags-From-Check
  Disable-Tags-From-Check
  Enable-Tags
  Disable-Tags
);

const my @VALID_BODY_FIELDS => qw(
  Tags
  Overridable
);

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
parents.  The first element of the list is the name of the profile
itself, the second is its parent and so on.

Note: This list is a reference. The contents should not be modified.

=item our_vendor

=item $prof->name

Returns the name of the profile, which may differ from the name used
to create this instance of the profile (e.g. due to symlinks).

=cut

has known_aliases => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has check_module_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has check_path_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has tag_names_for_check => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

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
    }
);

has enabled_checks_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has enabled_tags_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has files => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has known_tags_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has name => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);

has durable_tags_by_name => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has data => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $data = Lintian::Data->new;

        my @DATA_PATHS = $self->search_space('data');
        $data->data_paths(\@DATA_PATHS);
        $data->vendor($self->our_vendor);

        return $data;
    }
);

has parent_map => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

has profile_list => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] }
);

has our_vendor => (is => 'rw');

has include_dirs => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] }
);

# Temporary until aptdaemon (etc.) has been upgraded to handle
# Lintian loading code from user dirs.
# LP: #1162947
has safe_include_dirs => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] }
);

has known_vendors => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub {

        my $vendor = Dpkg::Vendor::get_current_vendor();
        croak encode_utf8('Could not determine the current vendor')
          unless $vendor;

        my @vendors;
        push(@vendors, lc $vendor);

        while ($vendor) {
            my $info = Dpkg::Vendor::get_vendor_info($vendor);
            # Cannot happen atm, but in case Dpkg::Vendor changes its internals
            #  or our code changes
            croak encode_utf8("Could not look up the parent vendor of $vendor")
              unless $info;

            $vendor = $info->{'Parent'};
            push(@vendors, lc $vendor)
              if $vendor;
        }

        return \@vendors;
    }
);

has user_dirs => (
    is => 'ro',
    lazy => 1,
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub {
        my ($self) = @_;

        my @user_data;

        # XDG user data
        push(@user_data, data_home('lintian'));

        # legacy per-user data
        push(@user_data, "$ENV{HOME}/.lintian")
          if length $ENV{HOME};

        # system wide user data
        push(@user_data, '/etc/lintian');

        const my @IMMUTABLE => grep { length && -e } @user_data;

        return \@IMMUTABLE;
    }
);

=item load ([$profname[, $ipath[, $extra]]])

Loads a new profile.  $profname is the name of the profile and $ipath
is a list reference containing the path to one (or more) Lintian
"roots".

If $profname is C<undef>, the default vendor will be loaded based on
Dpkg::Vendor::get_current_vendor.

If $ipath is not given, a default one will be used.

=cut

sub load {
    my ($self, $profile_name, $requested_dirs, $allow_user_dirs) = @_;

    $requested_dirs //= [];

    my @distribution_dirs = ($ENV{LINTIAN_BASE} // '/usr/share/lintian');

    const my @SAFE_INCLUDE_DIRS => (@{$requested_dirs}, @distribution_dirs);
    $self->safe_include_dirs(\@SAFE_INCLUDE_DIRS);

    my @all_dirs;

    push(@all_dirs, @{$self->user_dirs})
      if $allow_user_dirs && @{$self->user_dirs};

    push(@all_dirs, @{$self->safe_include_dirs});

    const my @ALL_INCLUDE_DIRS => @all_dirs;
    $self->include_dirs(\@ALL_INCLUDE_DIRS);

    for
      my $tagdir (map { ($_ // q{.}) . '/tags' } @{$self->safe_include_dirs}) {

        next
          unless -d $tagdir;

        my @tagpaths
          = File::Find::Rule->file->name(qw(*.tag *.desc))->in($tagdir);
        for my $tagpath (@tagpaths) {

            my $tag = Lintian::Tag->new;
            $tag->load($self, $tagpath);

            die encode_utf8("Tag in $tagpath is not associated with a check")
              unless length $tag->check;

            next
              if exists $self->known_tags_by_name->{$tag->name};

            $self->known_tags_by_name->{$tag->name} = $tag;
            $self->tag_names_for_check->{$tag->check} //= [];
            push(@{$self->tag_names_for_check->{$tag->check}},$tag->name);

            # record known aliases
            my @taken
              = grep { exists $self->known_aliases->{$_} }
              @{$tag->renamed_from};

            die encode_utf8('These aliases of the tag '
                  . $tag->name
                  . ' are taken already: '
                  . join($SPACE, @taken))
              if @taken;

            for my $old_name (@{$tag->renamed_from}) {

                if (exists $self->known_aliases->{$old_name}) {

                    my $taken = $self->known_aliases->{$old_name};
                    my $tag_name = $tag->name;
                    warn encode_utf8(
"Alias $old_name for $tag_name ignored; already taken by $taken"
                    );

                } else {
                    $self->known_aliases->{$old_name} = $tag->name;
                }
            }
        }
    }

    my @check_bases
      = map {(($_ // q{.}).'/lib/Lintian/Check', ($_ // q{.}).'/checks')}
      @{$self->safe_include_dirs};
    for my $check_base (@check_bases) {

        next
          unless -d $check_base;

        my @check_paths= File::Find::Rule->file->name('*.pm')->in($check_base);

        for my $absolute (@check_paths) {

            my $relative = path($absolute)->relative($check_base)->stringify;
            $relative =~ s{\.pm$}{};

            my $name = $relative;
            $name =~ s{([[:upper:]])}{-\L$1}g;
            $name =~ s{^-}{};
            $name =~ s{/-}{/}g;

            # ignore duplicates
            next
              if exists $self->check_module_by_name->{$name};

            $self->check_path_by_name->{$name} = $absolute;

            my $module = $relative;

            # replace slashes with double colons
            $module =~ s{/}{::}g;

            $self->check_module_by_name->{$name} = "Lintian::Check::$module";
        }
    }

    $self->read_profile($profile_name);

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
    my ($self, $maybe_historical) = @_;

    my $name = $self->get_current_name($maybe_historical);
    return undef
      unless length $name;

    return $self->known_tags_by_name->{$name}
      if exists $self->known_tags_by_name->{$name};

    return undef;
}

=item get_current_name

=cut

sub get_current_name {
    my ($self, $tag_name) = @_;

    return $self->known_aliases->{$tag_name}
      if exists $self->known_aliases->{$tag_name};

    return $tag_name
      if exists $self->known_tags_by_name->{$tag_name};

    return $EMPTY;
}

=item set_durable ($tag)

=cut

sub set_durable {
    my ($self, $maybe_historical, $status) = @_;

    my $tag = $self->get_tag($maybe_historical);
    croak encode_utf8("Unknown tag $maybe_historical.")
      unless defined $tag;

    $self->durable_tags_by_name->{$tag->name} = 1
      if $status;

    # settings from tag govern
    delete $self->durable_tags_by_name->{$tag->name}
      if !$status && !$tag->show_always;

    return;
}

=item $prof->is_durable ($tag)

Returns a false value if the tag has been marked as
"non-overridable".  Otherwise it returns a truth value.

=cut

sub is_durable {
    my ($self, $maybe_historical) = @_;

    my $tag = $self->get_tag($maybe_historical);
    croak encode_utf8("Unknown tag $maybe_historical.")
      unless defined $tag;

    return 1
      if $tag->show_always
      || exists $self->durable_tags_by_name->{$tag->name};

    return 0;
}

=item $prof->known_checks

=cut

sub known_checks {
    my ($self) = @_;

    return keys %{ $self->check_module_by_name };
}

=item $prof->enabled_checks

=cut

sub enabled_checks {
    my ($self) = @_;

    return keys %{ $self->enabled_checks_by_name };
}

=item $prof->enable_tag ($name)

Enables a tag.

=cut

sub enable_tag {
    my ($self, $maybe_historical) = @_;

    my $tag = $self->get_tag($maybe_historical);
    croak encode_utf8("Unknown tag $maybe_historical.")
      unless defined $tag;

    $self->enabled_checks_by_name->{$tag->check}++
      unless exists $self->enabled_tags_by_name->{$tag->name};

    $self->enabled_tags_by_name->{$tag->name} = 1;

    return;
}

=item $prof->disable_tag ($name)

Disable a tag.

=cut

sub disable_tag {
    my ($self, $maybe_historical) = @_;

    my $tag = $self->get_tag($maybe_historical);
    croak encode_utf8("Unknown tag $maybe_historical.")
      unless defined $tag;

    delete $self->enabled_checks_by_name->{$tag->check}
      unless exists $self->enabled_tags_by_name->{$tag->name}
      && --$self->enabled_checks_by_name->{$tag->check};

    delete $self->enabled_tags_by_name->{$tag->name};

    return;
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
        croak encode_utf8("$requested_name is not a valid profile name");
    }

    my @candidates;
    for my $include_dir ( map { ($_ // q{.}) . '/profiles' }
        @{$self->include_dirs} ) {
        push(@candidates, map { "$include_dir/$_.profile" } @search_space);
    }

    my $path = first_value { -e } @candidates;

    croak encode_utf8(
        'Could not find a profile matching: ' . join($SPACE, @search_space))
      unless length $path;

    my $deb822 = Lintian::Deb822->new;
    my @paragraphs = $deb822->read_file($path);

    my ($header, @sections) = @paragraphs;

    croak encode_utf8("Profile has no header in $path")
      unless defined $header;

    my $profile_name = $header->unfolded_value('Profile');
    croak encode_utf8("Profile has no name in $path")
      unless length $profile_name;

    croak encode_utf8("Invalid Profile field in $path")
      if $profile_name =~ m{^/} || $profile_name =~ m{\.};

    # normalize name
    $profile_name .= '/main'
      unless $profile_name =~ m{/};

    croak encode_utf8("Recursive definition of $profile_name")
      if exists $self->parent_map->{$profile_name};

    # Mark as being loaded.
    $self->parent_map->{$profile_name} = 0;

    $self->name($profile_name)
      unless length $self->name;

    $self->read_profile($header->unfolded_value('Extends'))
      if $header->declares('Extends');

    # prepend profile name after loading any parent
    unshift(@{$self->profile_list}, $profile_name);

    my @have_comma
      = grep { $header->value($_) =~ / , /sx } @VALID_HEADER_FIELDS;
    for my $section (@sections) {
        push(@have_comma,
            grep { $section->value($_) =~ / , /sx } @VALID_BODY_FIELDS);
    }

    warn
"Please use spaces as separators in field $_ instead of commas in profile $path\n"
      for uniq @have_comma;

    my @unknown_header_fields = $header->extra(@VALID_HEADER_FIELDS);
    croak encode_utf8("Unknown fields in header of profile $profile_name: "
          . join($SPACE, @unknown_header_fields))
      if @unknown_header_fields;

    my @enable_check_patterns
      = $header->trimmed_list('Enable-Tags-From-Check', $FIELD_SEPARATOR);
    my @disable_check_patterns
      = $header->trimmed_list('Disable-Tags-From-Check', $FIELD_SEPARATOR);

    my @enable_checks;
    for my $pattern (@enable_check_patterns) {
        push(@enable_checks, match_glob($pattern, $self->known_checks));
    }

    my @disable_checks;
    for my $pattern (@disable_check_patterns) {
        push(@disable_checks, match_glob($pattern, $self->known_checks));
    }

    my @action_checks = uniq(@enable_checks, @disable_checks);

    # make sure checks are loaded
    my @needed_checks
      = grep { !exists $self->check_module_by_name->{$_} } @action_checks;

    croak encode_utf8("Profile $profile_name references unknown checks: "
          . join($SPACE, @needed_checks))
      if @needed_checks;

    my @enable_tag_patterns
      = $header->trimmed_list('Enable-Tags', $FIELD_SEPARATOR);
    my @disable_tag_patterns
      = $header->trimmed_list('Disable-Tags', $FIELD_SEPARATOR);

    my @enable_tags;
    for my $pattern (@enable_tag_patterns) {
        push(@enable_tags, match_glob($pattern, $self->known_tags));
    }

    my @disable_tags;
    for my $pattern (@disable_tag_patterns) {
        push(@disable_tags, match_glob($pattern, $self->known_tags));
    }

    push(@enable_tags, @{$self->tag_names_for_check->{$_} // []})
      for uniq @enable_checks;

    push(@disable_tags, @{$self->tag_names_for_check->{$_} // []})
      for uniq @disable_checks;

    # disabling after enabling
    $self->enable_tag($_) for uniq @enable_tags;
    $self->disable_tag($_) for uniq @disable_tags;

    my $section_number = 2;

    for my $section (@sections){

        my @unknown_fields = $section->extra(@VALID_BODY_FIELDS);
        croak encode_utf8(
"Unknown fields in section $section_number of profile $profile_name: "
              . join($SPACE, @unknown_fields))
          if @unknown_fields;

        my @tags = $section->trimmed_list('Tags', $FIELD_SEPARATOR);
        croak encode_utf8(
"Tags field missing or empty in section $section_number of profile $profile_name"
        )unless @tags;

        my $overridable = $section->unfolded_value('Overridable') || 'yes';
        if ($overridable !~ / ^ -? \d+ $ /msx) {
            my $lowercase = lc $overridable;

            if ($lowercase =~ / ^ y(?:es)? | true $ /msx) {
                $overridable = 1;

            } elsif ($lowercase =~ / ^ n[o]? | false $ /msx) {
                $overridable = 0;

            } else {
                my $position = $section->position('Overridable');
                croak encode_utf8(
"$overridable is not a boolean value in profile $profile_name (line $position)"
                );
            }
        }

        for my $tag_name (@tags) {

            if ($overridable) {
                delete $self->durable_tags_by_name->{$tag_name};
            } else {
                $self->durable_tags_by_name->{$tag_name} = 1;
            }
        }

    } continue {
        $section_number++;
    }

    $self->our_vendor($self->profile_list->[0]);

    # honor tag settings regardless of profile
    my @show_always
      = grep { $_->show_always } values %{$self->known_tags_by_name};

    $self->durable_tags_by_name->{$_} = 1 for map { $_->name } @show_always;

    return;
}

=item display_level_for_tag

=cut

sub display_level_for_tag {
    my ($self, $tag_name) = @_;

    my $tag = $self->get_tag($tag_name);
    croak encode_utf8("Unknown tag $tag_name")
      unless defined $tag;

    return $self->display_level_lookup->{$tag->visibility};
}

=item tag_is_enabled(TAG)

=cut

sub tag_is_enabled {
    my ($self, $maybe_historical) = @_;

    my $tag = $self->get_tag($maybe_historical);
    croak encode_utf8("Unknown tag $maybe_historical.")
      unless defined $tag;

    return 1
      if exists $self->enabled_tags_by_name->{$tag->name};

    return 0;
}

=item display(OPERATION, RELATION, VISIBILITY)

Configure which tags are displayed by visibility.  OPERATION
is C<+> to display the indicated tags, C<-> to not display the indicated
tags, or C<=> to not display any tags except the indicated ones.  RELATION
is one of C<< < >>, C<< <= >>, C<=>, C<< >= >>, or C<< > >>.  The
OPERATION will be applied to all values of visibility that
match the given RELATION on the VISIBILITY argument.  If
either of those arguments are undefined, the action applies to any value
for that variable.  For example:

    $tags->display('=', '>=', 'error');

turns off display of all tags and then enables display of any tag of
visibility error or higher.

    $tags->display('+', '>', 'warning');

adds to the current configuration display of all tags with a visibility
higher than warning.

    $tags->display('-', '=', 'info');

turns off display of tags of visibility info.

This method throws an exception on errors, such as an unknown visibility or
an impossible constraint (like C<< > serious >>).

=cut

# Generate a subset of a list given the element and the relation.  This
# function makes a hard assumption that $rel will be one of <, <=, =, >=,
# or >.  It is not syntax-checked.
sub _relation_subset {
    my ($self, $element, $rel, @list) = @_;

    if ($rel eq $EQUAL) {
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

    return ()
      unless defined($found);

    if (length($rel) > 1) {
        return @list[$found .. $#list];

    }

    return ()
      if $found == $#list;

    return @list[($found + 1) .. $#list];
}

# Given the operation, relation, and visibility, produce a
# human-readable representation of the display level string for errors.
sub _format_level {
    my ($self, $op, $rel, $visibility) = @_;

    if (not defined $visibility) {
        return "$op $rel";
    } else {
        return "$op $rel $visibility (visibility)";
    }
}

sub display {
    my ($self, $op, $rel, $visibility) = @_;

    unless ($op =~ /^[+=-]\z/ and $rel =~ /^(?:[<>]=?|=)\z/) {
        my $error = $self->_format_level($op, $rel, $visibility);
        die encode_utf8('invalid display constraint ' . $error);
    }

    if ($op eq $EQUAL) {
        for my $s (@Lintian::Tag::VISIBILITIES) {
            $self->display_level_lookup->{$s} = 0;
        }
    }

    my $status = ($op eq $HYPHEN ? 0 : 1);

    my @visibilities;
    if ($visibility) {
        @visibilities
          = $self->_relation_subset($visibility, $rel,
            @Lintian::Tag::VISIBILITIES);
    } else {
        @visibilities = @Lintian::Tag::VISIBILITIES;
    }

    unless (@visibilities) {
        my $error = $self->_format_level($op, $rel, $visibility);
        die encode_utf8('invalid display constraint ' . $error);
    }

    for my $s (@visibilities) {
        $self->display_level_lookup->{$s} = $status;
    }

    return;
}

=item search_space

=cut

sub search_space {
    my ($self, $relative) = @_;

    my @base_dirs;
    for my $vendor (@{ $self->profile_list }) {

        push(@base_dirs, map { "$_/vendors/$vendor" } @{$self->include_dirs});
    }

    push(@base_dirs, @{$self->include_dirs});

    my @candidates = map { "$_/$relative" } @base_dirs;
    my @search_space = grep { -e } @candidates;

    return @search_space;
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

# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
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

## Represents a Lintian profile
package Lintian::Profile;

use base qw(Class::Accessor);

use strict;
use warnings;

use Carp qw(croak);
use Util qw(read_dpkg_control);

=head1 NAME

Lintian::Profile - Profile parser for Lintian

=head1 SYNOPSIS

 my @inc = ("$ENV{'HOME'}/.lintian/profiles/",
            '/etc/lintian/profiles/',
            "$ENV{'LINTIAN_ROOT'}/profiles/");
 # Check if the Ubuntu default profile is present.
 my $file = Lintian::Profile->find_profile('ubuntu', @inc);
 # Parse the debian profile (if available)
 my $profile = Lintian::Profile->new('debian', [@inc]);
 foreach my $tag ($profile->tags) {
     print "Enabled tag: $tag\n";
 }
 # ...

=head1 DESCRIPTION



=head1 CLASS METHODS

=over 4

=cut

# maps tag name to tag data.
my %TAG_MAP = ();
# maps check name to list of tag names.
my %CHECK_MAP = ();
# map of known valid severity allowed by profiles
my %SEVERITIES = (
    'pedantic'  => 1,
    'wishlist'  => 1,
    'minor'     => 1,
    'normal'    => 1,
    'important' => 1,
    'serious'   => 1,
    );

# List of fields in the main profile paragraph
my %MAIN_FIELDS = (
    'profile'                 => 1,
    'extends'                 => 1,
    'enable-tags-from-check'  => 1,
    'disable-tags-from-check' => 1,
    'enable-tags'             => 1,
    'disable-tags'            => 1,
    );

# List of fields in secondary profile paragraphs
my %SEC_FIELDS = (
    'tags'        => 1,
    'overridable' => 1,
    'severity'    => 1,
    );

# _load_checks
#
# Internal sub to load and fill up %TAG_MAP and %CHECK_MAP
sub _load_checks {
    my $root = $ENV{LINTIAN_ROOT} || '/usr/share/lintian';
    for my $desc (<$root/checks/*.desc>) {
        my ($header, @tags) = read_dpkg_control($desc);
        my $cname = $header->{'check-script'};
        my $tagnames = [];
        unless ($cname){
            croak "Missing Check-Script field in $desc.\n";
        }
        $CHECK_MAP{$cname} = $tagnames;
        for my $tag (@tags) {
            unless ($tag->{tag}) {
                croak "Missing Tag field in $desc.\n";
            }
            push @$tagnames, $tag->{tag};
            $tag->{info} = '' unless exists($tag->{info});
            $tag->{script} = $header->{'check-script'};
            $TAG_MAP{$tag->{tag}} = $tag;
        }
    }
}


=item Lintian::Profile->new($profname, $ppath)

Creates a new profile from the profile located by
using find_profile($profname, @$ppath).  $profname
is the name of the profile and $ppath is a list
reference containing the directories to search for
the profile and (if any) its parents.

=cut

sub new {
    my ($type, $name, $ppath) = @_;
    my $profile;
    croak "Illegal profile name \"$name\".\n"
        if $name =~ m,^/,o or $name =~ m/\./o;
    _load_checks() unless %TAG_MAP;
    my $self = {
        'parent-map'           => {},
        'parents'              => [],
        'profile-path'         => $ppath,
        'enabled-tags'         => {},
        'non-overridable-tags' => {},
        'severity-changes'     => {},
    };
    $self = bless $self, $type;
    $profile = $self->find_profile($name);
    croak "Cannot find profile $name (in " . join(', ', @$ppath).").\n"
        unless $profile;
    $self->_read_profile($profile);
    return $self;
}

=item $prof->parents

Returns a list ref of the names of its parents, in the order they are
applied.

Note: This list reference and its contents should not be modified.

=item $prof->name

Returns the name of the profile, which may differ from the name used
to create this instance of the profile (e.g. due to symlinks).

=cut

Lintian::Profile->mk_ro_accessors (qw(parents name));

=item $prof->tags

Returns the list of tags enabled in this profile.

Note: The contents of this list should not be modified.

=cut

sub tags {
    my ($self) = @_;
    return keys %{ $self->{'enabled-tags'} };
}

=item $prof->severity_changes

Returns a hashref mapping tag names to their altered severity.  If an
enabled tag is not present in this hashref, then it uses its normal
severity.  The altered severity may be the same as the normal
severity.

Note: This hashref nor its contents should be altered.

=cut

sub severity_changes {
    my ($self) = @_;
    return $self->{'severity-changes'};
}

=item $prof->non_overridable_tags

List of tags that has been marked as non-overridable.

Note: This list nor its contents should be modified.

=cut

sub non_overridable_tags {
    my ($self) = @_;
    return keys %{ $self->{'non-overridable-tags'} };
}

=item Lintian::Profile->find_profile($pname, @dirs), $prof->find_profile($pname[, @dirs])

This can both be used as a static or as an instance method.  If used
as an instance method, the @dirs argument may be omitted.

Finds a profile called $pname in the search directories (see below)
and returns the path to it.  If $pname does not contain a slash, then
it will look for a profile called "$pname/main" instead of $pname.

Returns a non-truth value if the profile could not be found.  $pname
cannot contain any dots.

Search Dirs: For the static call, only @dirs are considered.  For the
instance method @dirs is augmented with the search dirs present when
the object was created.

=cut

sub find_profile {
    my ($self, $pname, @dirs) = @_;
    my $pfile;
    croak "\"$pname\" is not a valid profile name.\n" if $pname =~ m/\./o;
    # Allow @dirs to override the default path for this profile-search
    if (ref $self) {
        push @dirs, @{ $self->{'profile-path'} } if defined $self->{'profile-path'};
    }
    # $vendor is short for $vendor/main
    $pname = "$pname/main" unless $pname =~ m,/,o;
    $pfile = "$pname.profile";
    foreach my $path (@dirs){
        return "$path/$pfile" if -e "$path/$pfile";
    }
    return '';
}


# $self->_read_profile($pfile)
#
# Parses the profile stored in the file $pfile; if this method returns
# normally, the profile will have been parsed successfully.
sub _read_profile {
    my ($self, $pfile) = @_;
    my @pdata;
    my $pheader;
    my $pmap = $self->{'parent-map'};
    my $pname;
    @pdata = read_dpkg_control($pfile, 0);
    $pheader = shift @pdata;
    croak "Profile field is missing from $pfile.\n"
        unless defined $pheader && $pheader->{'profile'};
    $pname = $pheader->{'profile'};
    croak "Invalid Profile field in $pfile.\n"
            if $pname =~ m,^/,o or $pname =~ m/\./o;
    croak "Recursive definition of $pname.\n"
        if exists $pmap->{$pname};
    $pmap->{$pname} = 0; # Mark as being loaded.
    $self->{'name'} = $pname unless exists $self->{'name'};
    if (exists $pheader->{'extends'} ){
        my $parent = $pheader->{'extends'};
        my $plist = $self->{'parents'};
        my $parentf;
        croak "Invalid Extends field in $pfile.\n"
            unless $parent && $parent !~ m/\./o;
        $parentf = $self->find_profile($parent);
        croak "Cannot find $parent, which $pname extends.\n"
            unless $parentf;
        $self->_read_profile($parentf);
        # Use the extends field in parents, even though the extended
        # profile might actually identity itself differently.
        push @$plist, $parent;
    }
    $self->_read_profile_tags($pname, $pheader);
    if (@pdata){
        my $i = 2; # section counter
        foreach my $psection (@pdata){
            $self->_read_profile_section($pname, $psection, $i++);
        }
    }
}


# $self->_read_profile_section($pname, $section, $sno)
#
# Parses and applies the effects of $section (a paragraph
# in the profile). $pname is the name of the profile and
# $no is section number (both of these are only used for
# error reporting).
sub _read_profile_section {
    my ($self, $pname, $section, $sno) = @_;
    my @tags = $self->_split_comma_sep_field($section->{'tags'});
    my $overridable = $self->_parse_boolean($section->{'overridable'}, -1, $pname, $sno);
    my $severity = $section->{'severity'}//'';
    my $noover = $self->{'non-overridable-tags'};
    my $sev_map = $self->{'severity-changes'};
    $self->_check_for_invalid_fields($section, \%SEC_FIELDS, $pname, "section $sno");
    croak "Profile \"$pname\" is missing Tags field (or it is empty) in section $sno.\n" unless @tags;
    croak "Profile \"$pname\" contains invalid severity \"$severity\" in section $sno.\n"
        if $severity && !$SEVERITIES{$severity};
    foreach my $tag (@tags) {
        croak "Unknown check $tag in $pname (section $sno).\n" unless exists $TAG_MAP{$tag};
        $sev_map->{$tag} = $severity if $severity;
        if ( $overridable != -1 ) {
            if ($overridable) {
                delete $noover->{$tag};
            } else {
                $noover->{$tag} = 1;
            }
        }
    }
}

# $self->_read_profile_tags($pname, $pheader)
#
# Interprets the {dis,en}able-tags{,-from-chcek} fields from
# the profile header $pheader.  $pname is the name of the
# profile (used for error reporting).
#
# If it returns, the enabled tags will be updated to reflect
#  the tags enabled/disabled by this profile (but not its
#  parents).
sub _read_profile_tags{
    my ($self, $pname, $pheader) = @_;
    $self->_check_for_invalid_fields($pheader, \%MAIN_FIELDS, $pname, 'profile header');
    $self->_check_duplicates($pname, $pheader, 'enable-tags-from-check', 'disable-tags-from-check');
    $self->_check_duplicates($pname, $pheader, 'enable-tags', 'disable-tags');
    my $tags_from_check_sub = sub {
        my ($field, $check) = @_;
        croak "Unknown check \"$check\" in profile \"$pname\".\n" unless exists $CHECK_MAP{$check};
        return @{$CHECK_MAP{$check}};
    };
    my $tag_sub = sub {
        my ($field, $tag) = @_;
        croak "Unknown tag \"$tag\" in profile \"$pname\".\n" unless exists $TAG_MAP{$tag};
        return $tag;
    };
    $self->_enable_tags_from_field($pname, $pheader, 'enable-tags-from-check', $tags_from_check_sub, 1);
    $self->_enable_tags_from_field($pname, $pheader, 'disable-tags-from-check', $tags_from_check_sub, 0);
    $self->_enable_tags_from_field($pname, $pheader, 'enable-tags', $tag_sub, 1);
    $self->_enable_tags_from_field($pname, $pheader, 'disable-tags', $tag_sub, 0);
}

# $self->_enable_tags_from_field($pname, $pheader, $field, $code, $enable)
#
# Parse $field in $pheader as a comma separated list of items; these items are then
# passed to $code, that must returns a list of tags.  If $enable is a truth value
# these tags are enabled in the profile, otherwise they are disabled.
sub _enable_tags_from_field {
    my ($self, $pname, $pheader, $field, $code, $enable) = @_;
    my $tags = $self->{'enabled-tags'};
    return unless $pheader->{$field};
    foreach my $tag (map { $code->($field, $_) } $self->_split_comma_sep_field($pheader->{$field})){
        if($enable) {
            $tags->{$tag} = 1;
        } else {
            delete $tags->{$tag};
        }
    }
}


# $self->_check_duplicates($name, $map, @fields)
#
# Checks the @fields in $map for duplicate values.  The
# values are parsed as comma-separated lists.  The same
# entry in these lists are not allowed twice, regardless
# of they appear twice in the same field or once in two
# different fields of @fields.
#
#
sub _check_duplicates{
    my ($self, $name, $map, @fields) = @_;
    my %dupmap;
    foreach my $field (@fields) {
        next unless exists $map->{$field};
        foreach my $element (split m/\s*+,\s*+/o, $map->{$field}){
            if (exists $dupmap{$element}){
                my $other = $dupmap{$element};
                croak "\"$element\" appears in both \"$field\" and \"$other\" in profile \"$name\".\n"
                    unless $other eq $field;
                croak "\"$element\" appears twice in the field \"$field\" in profile \"$name\".\n";
            }
            $dupmap{$element} = $field;
        }
    }
}

# $self->_parse_boolean($bool, $def, $pname, $sno);
#
# Parse $bool as a string representing a bool; if undefined return $def.
# $pname and $sno are the Profile name and section number - used for
# error reporting.
sub _parse_boolean {
    my ($self, $bool, $def, $pname, $sno) = @_;
    return $def unless defined $bool;
    $bool = lc $bool;
    return 1 if $bool eq 'yes' || $bool eq 'true' ||
        ($bool =~ m/^\d++$/o && $bool != 0);
    return 0  if $bool eq 'no' || $bool eq 'false' ||
        ($bool =~ m/^\d++$/o && $bool == 0);
    croak "\"$bool\" is not a boolean value in $pname (section $sno).\n";
}

# $self->_split_comma_sep_field($data)
#
# Split $data as a comma-separated list of items (whitespace will
# be ignored).
sub _split_comma_sep_field {
    my ($self, $data) = @_;
    return () unless defined $data;
    # remove trailing and leading white-space
    $data =~ s/^\s++//o;
    $data =~ s/\s++$//o;
    return split m/\s*,\s*/o, $data;
}

# $self->_check_for_invalid_fields($para, $known, $pname, $paraname)
#
# Check $para for unknown fields (e.g. fields not in $known).
# If an unknown field is found, croak using $pname and $paraname
# to identify the profile name and paragraph (respectively)
sub _check_for_invalid_fields {
    my ($self, $para, $known, $pname, $paraname) = @_;
    foreach my $field (keys %$para) {
        next if exists $known->{$field};
        croak "Unknown field \"$field\" in $pname ($paraname).\n";
    }
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

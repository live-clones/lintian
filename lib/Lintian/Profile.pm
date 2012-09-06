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

use Lintian::CheckScript;
use Lintian::Util qw(parse_boolean read_dpkg_control);

=head1 NAME

Lintian::Profile - Profile parser for Lintian

=head1 SYNOPSIS

 # Load the debian profile (if available)
 my $profile = Lintian::Profile->new ('debian', $ENV{'LINTIAN_ROOT'});
 # Load the debian profile using an explicit search path
 $profile = Lintian::Profile->new ('debian', $ENV{'LINTIAN_ROOT'},
    ['/path/to/profiles', "$ENV{'LINTIAN_ROOT'}/profiles"]);
 # Load the "default" profile for the current vendor
 $profile = Lintian::Profile->new (undef, $ENV{'LINTIAN_ROOT'});
 foreach my $tag ($profile->tags) {
     print "Enabled tag: $tag\n";
 }
 # ...

=head1 DESCRIPTION

Lintian::Profile handles finding, parsing and implementation of
Lintian Profiles as well as loading the relevant Lintian checks.

=head1 CLASS METHODS

=over 4

=cut

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

=item Lintian::Profile->new($profname, $root[, $ppath])

Creates a new profile from the profile located by using
find_profile($profname, @$ppath).  $profname is the name of the
profile and $ppath is a list reference containing the directories to
search for the profile and (if any) its parents.  $root is the
"LINTIAN_ROOT" and is used for finding checks.

If $profname is C<undef>, the default vendor will be loaded based on
Dpkg::Vendor::get_current_vendor.

If $ppath is not given, a default one will be used.

=cut

sub new {
    my ($type, $name, $root, $ppath) = @_;
    my $profile;
    $ppath = [_default_inc_path ($root)] unless $ppath;
    my $self = {
        'parent-map'           => {},
        'profile_list'         => [],
        'profile-path'         => $ppath,
        'enabled-tags'         => {}, # "set" of tags enabled (value is largely ignored)
        'enabled-checks'       => {}, # maps script to the number of tags enabled (0 if disabled)
        'non-overridable-tags' => {},
        'severity-changes'     => {},
        'check-scripts'        => {}, # maps script name to Lintian::CheckScript
        'known-tags'           => {}, # maps tag name to Lintian::Tag::Info
        'root'         => $root,
    };
    $self = bless $self, $type;
    if (not defined $name) {
        ($profile, $name) = $self->_find_vendor_profile;
    } else {
        croak "Illegal profile name \"$name\""
            if $name =~ m,^/,o or $name =~ m/\./o;
        $profile = $self->_find_profile ($name);
    }
    croak "Cannot find profile $name (in " . join(', ', @$ppath).")"
        unless $profile;
    $self->_read_profile($profile);
    return $self;
}

=item $prof->profile_list

Returns a list ref of the (normalized) names of the profile and its
parents.  The last element of the list is the name of the profile
itself, the second last is its parent and so on.

Note: This list reference and its contents should not be modified.

=item $prof->name

Returns the name of the profile, which may differ from the name used
to create this instance of the profile (e.g. due to symlinks).

=item $prof->root

Returns the LINTIAN_ROOT associated with the profile.

=cut

Lintian::Profile->mk_ro_accessors (qw(profile_list name root));

=item $prof->tags([$known])

Returns the list of tags in this profile.  If $known is given
and it is a truth value, the list of known tags is returned.
Otherwise only the enabled tags will be returned.

Note: The contents of this list should not be modified.

=cut

sub tags {
    my ($self, $known) = @_;
    return keys %{ $self->{'known-tags'} } if $known;
    return keys %{ $self->{'enabled-tags'} };
}

=item $prof->scripts ([$known])

Returns the list of Check-Scripts in this profile.  If $known
is given and it is a truth value, the list of known Check-Scripts
is returned.  Otherwise only checks with an enabled tag will be
enabled.

=cut

sub scripts {
    my ($self, $known) = @_;
    return keys %{ $self->{'check-scripts'} } if $known;
    return keys %{ $self->{'enabled-checks'} };
}

=item $prof->is_overridable ($tag)

Returns a false value if the tag has been marked as
"non-overridable".  Otherwise it returns a truth value.

=cut

sub is_overridable {
    my ($self, $tag) = @_;
    return ! exists $self->{'non-overridable-tags'}->{$tag};
}

=item $prof->get_tag ($tag[, $known])

Returns the Lintian::Tag::Info for $tag if it is enabled for the
profile (or just a "known tag" if $known is given and a truth value).
Otherwise it returns undef.

=cut

sub get_tag {
    my ($self, $tag, $known) = @_;
    return unless $known || exists $self->{'enabled-tags'}->{$tag};
    return $self->{'known-tags'}->{$tag};
}

=item $prof->get_script ($script[, $known])

Returns the Lintian::CheckScript for $script if it is enabled for the
profile (or just a "known script" if $known is given and a truth value).
Otherwise it returns undef.

Note: A script is enabled as long as at least one of the tags it
provides are enabled.

=cut

sub get_script {
    my ($self, $script, $known) = @_;
    return unless $known || exists $self->{'enabled-checks'}->{$script};
    return $self->{'check-scripts'}->{$script};
}

=item $prof->enable_tags (@tags)

Enables all tags named in @tags.  Croaks if an unknown tag is found.

=cut

sub enable_tags {
    my ($self, @tags) = @_;
    for my $tag (@tags) {
        my $ti = $self->{'known-tags'}->{$tag};
        croak "Unknown tag $tag" unless $ti;
        next if exists $self->{'enabled-tags'}->{$tag};
        $self->{'enabled-tags'}->{$tag} = 1;
        $self->{'enabled-checks'}->{$ti->script}++;
    }
}

=item $prof->disable_tags (@tags)

Disable all tags named in @tags.  Croaks if an unknown tag is found.

=cut

sub disable_tags {
    my ($self, @tags) = @_;
    for my $tag (@tags) {
        my $ti = $self->{'known-tags'}->{$tag};
        croak "Unknown tag $tag" unless $ti;
        next unless exists $self->{'enabled-tags'}->{$tag};
        delete $self->{'enabled-tags'}->{$tag};
        $self->{'enabled-checks'}->{$ti->script}--;
    }
}

# $prof->_find_profile ($pname)
#
# Finds a profile called $pname in the search directories and returns
# the path to it.  If $pname does not contain a slash, then it will look
# for a profile called "$pname/main" instead of $pname.
#
# Returns a non-truth value if the profile could not be found.  $pname
# cannot contain any dots.

sub _find_profile {
    my ($self, $pname) = @_;
    my $pfile;
    croak "\"$pname\" is not a valid profile name" if $pname =~ m/\./o;
    # $vendor is short for $vendor/main
    $pname = "$pname/main" unless $pname =~ m,/,o;
    $pfile = "$pname.profile";
    foreach my $path (@{ $self->{'profile-path'} }){
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
    my $plist = $self->{'profile_list'};
    @pdata = read_dpkg_control($pfile, 0);
    $pheader = shift @pdata;
    croak "Profile field is missing from $pfile"
        unless defined $pheader && $pheader->{'profile'};
    $pname = $pheader->{'profile'};
    croak "Invalid Profile field in $pfile"
            if $pname =~ m,^/,o or $pname =~ m/\./o;

    # Normalize the profile name
    $pname .= '/main' unless $pname =~m,/,;

    croak "Recursive definition of $pname"
        if exists $pmap->{$pname};
    $pmap->{$pname} = 0; # Mark as being loaded.
    $self->{'name'} = $pname unless exists $self->{'name'};
    if (exists $pheader->{'extends'} ){
        my $parent = $pheader->{'extends'};
        my $parentf;
        croak "Invalid Extends field in $pfile"
            unless $parent && $parent !~ m/\./o;
        $parentf = $self->_find_profile ($parent);
        croak "Cannot find $parent, which $pname extends"
            unless $parentf;
        $self->_read_profile($parentf);
    }

    # Add the profile to the "chain" after loading its parent (if
    # any).
    push @$plist, $pname;

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
    croak "Profile \"$pname\" is missing Tags field (or it is empty) in section $sno" unless @tags;
    croak "Profile \"$pname\" contains invalid severity \"$severity\" in section $sno"
        if $severity && !$SEVERITIES{$severity};
    foreach my $tag (@tags) {
        croak "Unknown check $tag in $pname (section $sno)" unless $self->{'known-tags'}->{$tag};
        if ($severity) {
            $self->{'known-tags'}->{$tag}->set_severity ($severity);
            $sev_map->{$tag} = $severity;
        }
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

        unless (exists $self->{'check-scripts'}->{$check}) {
            $self->_load_check ($pname, $check);
        }
        return $self->{'check-scripts'}->{$check}->tags;
    };
    my $tag_sub = sub {
        my ($field, $tag) = @_;
        unless (exists $self->{'known-tags'}->{$tag}) {
            $self->_load_checks($pname);
            croak "Unknown tag \"$tag\" in profile \"$pname\""
                unless exists $self->{'known-tags'}->{$tag};
        }
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
    my $method = \&enable_tags;
    my @tags;
    $method = \&disable_tags unless $enable;
    return unless $pheader->{$field};
    @tags = map { $code->($field, $_) } $self->_split_comma_sep_field($pheader->{$field});
    $self->$method (@tags);
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
                croak "\"$element\" appears in both \"$field\" and \"$other\" in profile \"$name\""
                    unless $other eq $field;
                croak "\"$element\" appears twice in the field \"$field\" in profile \"$name\"";
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
    my $val;
    return $def unless defined $bool;
    eval { $val = parse_boolean ($bool); };
    croak "\"$bool\" is not a boolean value in $pname (section $sno)"
        if $@;
    return $val;
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
        croak "Unknown field \"$field\" in $pname ($paraname)";
    }
}

sub _load_check {
    my ($self, $profile, $check) = @_;
    my $root = $self->root;
    my $cf = "$root/checks/${check}.desc";
    croak "$profile references unknown $check" unless -f $cf;
    my $c = Lintian::CheckScript->new ($cf);
    return if $self->{'check-scripts'}->{$c->name};
    $self->{'check-scripts'}->{$c->name} = $c;
    for my $tn ($c->tags) {
        if ($self->{'known-tags'}->{$tn}) {
            my $ocn = $self->{'known-tags'}->{$tn}->script;
            croak $c->name . " redefined tag $tn which was defined by $ocn";
        }
        $self->{'known-tags'}->{$tn} = $c->get_tag ($tn);
    }
}

sub _load_checks {
    my ($self, $profile) = @_;
    my $root = $self->root;
    opendir my $dirfd, "$root/checks" or croak "opendir $root/checks: $!";
    for my $desc (sort readdir $dirfd) {
        next unless $desc =~ s/\.desc$//o;
        $self->_load_check($profile, $desc);
    }
    closedir $dirfd;
}

sub _default_inc_path {
    my ($root) = @_;
    my @path = ();
    push @path, "$ENV{'HOME'}/.lintian/profiles"
        if exists $ENV{'HOME'} and defined $ENV{'HOME'};
    push @path, '/etc/lintian/profiles', "$root/profiles";
    return @path;
}

sub _find_vendor_profile {
    my ($self) = @_;
    require Dpkg::Vendor;
    my $vendor = Dpkg::Vendor::get_current_vendor ();
    croak "Could not determine the current vendor"
        unless $vendor;
    my $orig = $vendor; # copy
    while ($vendor) {
        my $file = $self->_find_profile (lc $vendor);
        return ($file, $vendor) if $file;
        my $info = Dpkg::Vendor::get_vendor_info ($vendor);
        # Cannot happen atm, but in case Dpkg::Vendor changes its internals
        #  or our code changes
        croak "Could not look up the parent vendor of $vendor"
            unless $info;
        $vendor = $info->{'Parent'};
    }
    croak "Could not find a profile for vendor $orig";
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

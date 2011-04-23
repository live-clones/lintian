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

use Util;

# maps tag name to tag data.
my %TAG_MAP = ();
# maps check name to list of tag names.
my %CHECK_MAP = ();

sub _load_checks {
    my $root = $ENV{LINTIAN_ROOT} || '/usr/share/lintian';
    for my $desc (<$root/checks/*.desc>) {
        my ($header, @tags) = read_dpkg_control($desc);
        my $cname = $header->{'check-script'};
        my $tagnames = [];
        unless ($cname){
            fail("missing Check-Script field in $desc");
        }
        $CHECK_MAP{$cname} = $tagnames;
        for my $tag (@tags) {
            unless ($tag->{tag}) {
                fail("missing Tag field in $desc");
            }
            push @$tagnames, $tag->{tag};
            $tag->{info} = '' unless exists($tag->{info});
            $tag->{script} = $header->{'check-script'};
            $TAG_MAP{$tag->{tag}} = $tag;
        }
    }
}

sub new {
    my ($type, $name, $ppath) = @_;
    my $profile;
    fail "Illegal profile name $name\n"
        if $name =~ m,^/,o or $name =~ m/\./o;
    _load_checks() unless %TAG_MAP;
    my $self = {
        'parent-map' => {},
        'parents' => [],
        'profile-path' => $ppath,
        'enabled-tags' => {},
    };
    $self = bless $self, $type;
    $profile = $self->_find_profile($name);
    fail "Cannot find $name.\n" unless $profile;
    $self->_read_profile($profile);
    return $self;
}

Lintian::Profile->mk_ro_accessors (qw(parents name));

sub tags {
    my ($self) = @_;
    return keys %{ $self->{'enabled-tags'} };
}

sub _find_profile {
    my ($self, $pname) = @_;
    my $pfile;
    fail "$pname is not a valid profile name\n" if $pname =~ m/\./o;
    # $vendor is short for $vendor/main
    $pname = "$pname/main" unless $pname =~ m,/,o;
    $pfile = "$pname.profile";
    foreach my $path (@{ $self->{'profile-path'} }){
        return "$path/$pfile" if -e "$path/$pfile";
    }
    return '';
}

sub _read_profile {
    my ($self, $pfile) = @_;
    my @pdata;
    my $pheader;
    my $pmap = $self->{'parent-map'};
    my $pname;
    open(my $fd, '<', $pfile) or fail "$pfile: $!";
    @pdata = parse_dpkg_control($fd, 0);
    close $fd;
    $pheader = $pdata[0];
    fail "Profile field is missing from $pfile."
        unless defined $pheader && $pheader->{'profile'};
    $pname = $pheader->{'profile'};
    fail "Invalid Profile field in $pfile.\n"
            if $pname =~ m,^/,o or $pname =~ m/\./o;
    $pmap->{$pname} = 0; # Mark as being loaded.
    $self->{'name'} = $pname unless exists $self->{'name'};
    if (exists $pheader->{'extends'} ){
        my $parent = $pheader->{'extends'};
        my $plist = $self->{'parents'};
        my $parentf;
        fail "Invalid Extends field in $pfile.\n"
            unless $parent && $parent !~ m/\./o;
        fail "Recursive definition of $parent.\n"
            if exists $pmap->{$parent};
        $parentf = $self->_find_profile($parent);
        fail "Cannot find $parent, which $pname extends.\n"
            unless $parentf;
        $self->_read_profile($parentf);
        push @$plist, $parent;
    }
    $self->_read_profile_tags($pname, $pheader);
}

sub _read_profile_tags{
    my ($self, $pname, $pheader) = @_;
    Lintian::Profile::_check_duplicates($pname, $pheader, 'enable-tags-from-check', 'disable-tags-from-check');
    Lintian::Profile::_check_duplicates($pname, $pheader, 'enable-tag', 'disable-tag');
    my $tags_from_check_sub = sub {
        my ($field, $check) = @_;
        fail "Unknown check $check in $pname\n" unless exists $CHECK_MAP{$check};
        return @{$CHECK_MAP{$check}};
    };
    my $tag_sub = sub {
        my ($field, $tag) = @_;
        fail "Unknown check $tag in $pname\n" unless exists $TAG_MAP{$tag};
        return $tag;
    };
    $self->_enable_tags_from_field($pname, $pheader, 'enable-tags-from-check', $tags_from_check_sub, 1);
    $self->_enable_tags_from_field($pname, $pheader, 'disable-tags-from-check', $tags_from_check_sub, 0);
    $self->_enable_tags_from_field($pname, $pheader, 'enable-tag', $tag_sub, 1);
    $self->_enable_tags_from_field($pname, $pheader, 'disable-tag', $tag_sub, 0);
}

sub _enable_tags_from_field {
    my ($self, $pname, $pheader, $field, $code, $enable) = @_;
    my $tags = $self->{'enabled-tags'};
    return unless $pheader->{$field};
    foreach my $tag (map { $code->($field, $_) } split m/\s*+,\s*+/o, $pheader->{$field}){
        if($enable) {
            $tags->{$tag} = 1;
        } else {
            delete $tags->{$tag};
        }
    }
}

sub _check_duplicates{
    my ($name, $map, @fields) = @_;
    my %dupmap;
    foreach my $field (@fields) {
        next unless exists $map->{$field};
        foreach my $element (split m/\s*+,\s*+/o, $map->{$field}){
            if (exists $dupmap{$element}){
                my $other = $dupmap{$element};
                fail "$element appears in both $field and $other in $name.\n"
                    unless $other eq $field;
                fail "$element appears twice in $field in $name.\n";
            }
            $dupmap{$element} = $field;
        }
    }
}

1;

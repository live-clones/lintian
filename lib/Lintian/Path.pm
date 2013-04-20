# -*- perl -*-
# Lintian::Path -- Representation of path entry in a package

# Copyright (C) 2011 Niels Thykier
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Path;

use strict;
use warnings;

use parent qw(Class::Accessor);

use Carp qw(croak);

use Lintian::Util qw(normalize_pkg_path);

=head1 NAME

Lintian::Path - Lintian representation of a path entry in a package

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('lintian', 'source', '/path/to/entry');
    my $info = Lintian::Collect->new ($name, $type, $dir);
    my $path = $info->index('bin/ls');
    if ($path->is_file) {
       # is file (or hardlink)
       if ($path->is_hardlink) { }
       if ($path->is_regular_file) { }
    } elsif ($path->is_dir) {
       # is dir
       if ($path->owner eq 'root') { }
       if ($path->group eq 'root') { }
    } elsif ($path->is_symlink) {
       my $resolved = $path->link_resolved;
       if (defined $resolved) {
           # is a resolvable symlink (pointing to $target)
           my $more_info = $info->index($resolved);
       }
    }

=head1 INSTANCE METHODS

=over 4

=item Lintian::Path->new ($data)

Internal constructor (used by Lintian::Collect::Package).

Argument is a hash containing the data read from the index file.

=cut

sub new {
    my ($type, $data) = @_;
    my $self = {
        # copy the data into $self
        %$data,
    };
    return bless $self, $type;
}

=item name

Returns the name of the file (relative to the package root).

NB: It will never have any leading "./" (or "/") in it.

=item owner

Returns the owner of the path entry as a username.

NB: If only numerical owner information is available in the package,
this may return a numerical owner (except uid 0 is always mapped to
"root")

=item group

Returns the group of the path entry as a username.

NB: If only numerical owner information is available in the package,
this may return a numerical group (except gid 0 is always mapped to
"root")

=item uid

Returns the uid of the owner of the path entry.

NB: If the uid is not available, undef will be returned.
This usually happens if the numerical data is not collected (e.g. in
source packages)

=item gid

Returns the gid of the owner of the path entry.

NB: If the gid is not available, undef will be returned.
This usually happens if the numerical data is not collected (e.g. in
source packages)

=item link

If this is a link (i.e. is_symlink or is_hardlink returns a truth
value), this method returns the target of the link.

If this is not a link, then this returns undef.

If the path is a symlink this method can be used to determine if the
symlink is relative or absolute.  This is I<not> true for hardlinks,
where the link target is always relative to the root.

NB: Even for symlinks, a leading "./" will be stripped.

=item size

Returns the size of the path in bytes.

NB: This is only well defined for files.

=item date

Return the modification date as YYYY-MM-DD.

=item operm

Returns the file permissions of this object in octal (e.g. 0644).

NB: This is only well defined for file entries that are subject to
permissions (e.g. files).  Particularly, the value is not well defined
for symlinks.

=item dirname

Returns the "directory" part of the name, similar to dirname(1) or
File::Basename::dirname.  The dirname will end with a trailing slash
(except the "root" dir - see below).

NB: Returns the empty string for the "root" dir.

=item basename

Returns the "filename" part of the name, similar basename(1) or
File::Basename::basename (without passing a suffix to strip in either
case).  For dirs, the basename will end with a trailing slash (except
for the "root" dir - see below).

NB: Returns the empty string for the "root" dir.

=cut

Lintian::Path->mk_ro_accessors (qw(name owner group link type uid gid
  size date operm dirname basename
));

=item children

Returns a list of children (as Lintian::Path objects) of this entry.
The list and its contents should not be modified.

NB: Returns the empty list for non-dir entries.

=cut

sub children {
    my ($self) = @_;
    return @{ $self->{'children'} };
}

# Backing method implementing the is_X tests
sub _is_type {
    my ($self, $t) = @_;
    return $self->type eq $t;
}

=item is_symlink

Returns a truth value if this entry is a symlink.

=item is_hardlink

Returns a truth value if this entry is a hardlink to a regular file.

NB: The target of a hardlink is always a regular file (and not a dir etc.).

=item is_dir

Returns a truth value if this entry is a dir.

NB: Unlike the "-d $dir" operator this will never return true for
symlinks, even if the symlink points to a dir.

=item is_file

Returns a truth value if this entry is a regular file (or a hardlink to one).

NB: Unlike the "-f $dir" operator this will never return true for
symlinks, even if the symlink points to a file (or hardlink).

=item is_regular_file

Returns a truth value if this entry is a regular file.

This is eqv. to $path->is_file and not $path->is_hardlink.

NB: Unlike the "-f $dir" operator this will never return true for
symlinks, even if the symlink points to a file.

=cut

sub is_symlink { return $_[0]->_is_type ('l'); }
sub is_hardlink { return $_[0]->_is_type ('h'); }
sub is_dir { return $_[0]->_is_type ('d'); }
sub is_file { return $_[0]->_is_type ('-') || $_[0]->_is_type ('h'); }
sub is_regular_file  { return $_[0]->_is_type ('-'); }

=item link_resolved

Resolve the link and return the resolved name.  If the link cannot be
resolved or it is unsafe to resolve, this method returns undef.

NB: This method will return the empty string for links pointing to the
root dir of the package.

Only available on "links" (i.e. symlinks or hardlinks).  On non-links
this will croak.

B<CAVEAT>: This method is I<not always sufficient> to test if it is
safe to open a given symlink.  Use
L<is_ancestor_of|Lintian::Util/is_ancestor_of(PARENTDIR, PATH)> for
that.  If you must use this method, remember to check that the target
is not a symlink (or if it is, that it can be resolved).

=cut

sub link_resolved {
    my ($self) = @_;
    return $self->{'link_target'} if exists $self->{'link_target'};
    my $name = $self->name;
    my $link = $self->link;
    croak "$name is not a link" unless defined $link;
    my $dir = $self->dirname;
    # hardlinks are always relative to the package root
    $dir = '/' if $self->is_hardlink;
    my $target = normalize_pkg_path($dir, $link);
    if ($target) {
        # map "." to ''.
        $target = '' if $target eq '.';
    } else {
        $target = undef;
    }
    $self->{'link_target'} = $target;
    return $target;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect(3), Lintian::Collect::Binary(3),
Lintian::Collect::Source(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et


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
use parent qw(Class::Accessor::Fast);
use overload (
    '""' => \&_as_string,
    'qr' => \&_as_regex_ref,
    'bool' => \&_bool,
    '!' => \&_bool_not,
    '.'  => \&_str_concat,
    'cmp' => \&_str_cmp,
    'eq' => \&_str_eq,
    'ne' => \&_str_ne,
    'fallback' => 0,
);

use Carp qw(croak confess);
use Scalar::Util qw(weaken);

use Lintian::Util qw(is_ancestor_of normalize_pkg_path parse_dpkg_control);

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
       my $normalized = $path->link_normalized;
       if (defined($normalized)) {
           my $more_info = $info->index($normalized);
           if (defined($more_info)) {
               # target exists in the package...
           }
       }
    }

=head1 INSTANCE METHODS

=over 4

=item Lintian::Path->new ($data)

Internal constructor (used by Lintian::Collect::Package).

Argument is a hash containing the data read from the index file.

=cut

sub new {
    my ($type, $data, $collect, $path_sub) = @_;
    my $self = {
        # copy the data into $self
        %$data,
    };
    weaken($self->{'_collect'} = $collect);
    $self->{'_collect_path_sub'} = $path_sub;
    bless($self, $type);
    if ($self->is_file or $self->is_dir) {
        $self->{'_is_open_ok'} = $self->is_file;
        $self->{'_valid_path'} = 1;
    }
    return $self;
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

Lintian::Path->mk_ro_accessors(
    qw(name owner group link type uid gid
      size date operm dirname basename
      ));

=item children

Returns a list of children (as Lintian::Path objects) of this entry.
The list and its contents should not be modified.

NB: Returns the empty list for non-dir entries.

=cut

sub children {
    my ($self) = @_;
    return sort(values(%{ $self->{'children'} })) if wantarray;
    return values(%{ $self->{'children'} });
}

=item child(BASENAME)

Returns the child named BASENAME if it is a child of this directory.
Otherwise, this method returns C<undef>.

For non-dirs, this method always returns C<undef>.

=cut

sub child {
    my ($self, $basename) = @_;
    my $children = $self->{'children'};
    my ($child, $had_trailing_slash);

    # Remove the trailing slash (for dirs)
    if (substr($basename, -1, 1) eq '/') {
        $basename = substr($basename, 0, -1);
        $had_trailing_slash = 1;
    }
    return if not $children or not exists($children->{$basename});
    $child = $children->{$basename};
    # Only directories are allowed to be fetched with trailing slash.
    return if $had_trailing_slash and not $child->is_dir;
    return $child;
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

sub is_symlink { return $_[0]->type eq 'l'; }
sub is_hardlink { return $_[0]->type eq 'h'; }
sub is_dir { return $_[0]->type eq 'd'; }
sub is_file { return $_[0]->type eq '-' || $_[0]->type eq 'h'; }
sub is_regular_file  { return $_[0]->type eq '-'; }

=item link_normalized

Returns the target of the link normalized against it's directory name.
If the link cannot be normalized or normalized path might escape the
package root, this method returns C<undef>.

NB: This method will return the empty string for links pointing to the
root dir of the package.

Only available on "links" (i.e. symlinks or hardlinks).  On non-links
this will croak.

B<CAVEAT>: This method is I<not always sufficient> to test if it is
safe to open a given symlink.  Use
L<is_ancestor_of|Lintian::Util/is_ancestor_of(PARENTDIR, PATH)> for
that.  If you must use this method, remember to check that the target
is not a symlink (or if it is, that it can be resolved safely).

=cut

sub link_normalized {
    my ($self) = @_;
    return $self->{'link_target'} if exists $self->{'link_target'};
    my $name = $self->name;
    my $link = $self->link;
    croak "$name is not a link" unless defined $link;
    my $dir = $self->dirname;
    # hardlinks are always relative to the package root
    $dir = '/' if $self->is_hardlink;
    my $target = normalize_pkg_path($dir, $link);
    $self->{'link_target'} = $target;
    return $target;
}

=item fs_path

Returns the path to this object on the file system.

This may fail if the object is dangling symlink or traverses a symlink
outside the package root.

To test if this is safe to call, use L</is_valid_path>.

B<CAVEAT>: This does I<not> validate that the file object is generally
safe to work with.  If you intend to open the file object, you should
use L</open([LAYER])> instead or at least test it with L</is_open_ok>.

=cut

sub fs_path {
    my ($self) = @_;
    my $path = $self->_collect_path($self);
    $self->_check_access($path);
    return $path;
}

=item is_open_ok

Returns a truth value if it is safe to attempt open a read handle to
the underlying file object.

Returns a truth value if the path may be opened.

=cut

sub is_open_ok {
    my ($self) = @_;
    return $self->{'_is_open_ok'} if exists($self->{'_is_open_ok'});
    eval {
        my $path = $self->_collect_path($self);
        $self->_check_open($path);
    };
    return if $@;
    return 1;
}

=item is_valid_path

Returns a truth value if the path is contained with the package root.

=cut

sub is_valid_path {
    my ($self) = @_;
    return $self->{'_valid_path'} if exists($self->{'_valid_path'});
    eval {$self->fs_path;};
    return if $@;
    return 1;
}

sub _collect_path {
    my ($self, $path) = @_;
    my $collect = $self->{'_collect'};
    my $collect_sub = $self->{'_collect_path_sub'};
    if (not defined($collect_sub)) {
        confess($self->name . ' does not have an underlying FS object');
    }
    return $collect->$collect_sub($path) if $path;
    return $collect->$collect_sub();
}

sub _check_access {
    my ($self, $path) = @_;
    my $safe = 1;
    if (exists($self->{'_valid_path'})) {
        $safe = $self->{'_valid_path'};
    } else {
        my $root_path = $self->_collect_path;
        if (!-e $path || !is_ancestor_of($root_path, $path)) {
            $safe = 0;
        }
    }
    if (not $safe) {
        $self->{'_valid_path'} = $self->{'_is_open_ok'} = 0;
        # NB: We are deliberately vague here to avoid suggesting
        # whether $path exists.  In some cases (e.g. lintian.d.o)
        # the output is readily available to wider public.
        confess('Attempt to access through broken or unsafe symlink:'. ' '
              . $self->name);
    }
    $self->{'_valid_path'} = 1;
    return 1;
}

sub _check_open {
    my ($self, $path) = @_;
    $self->_check_access($path);
    # Symlinks can point to a "non-file" object inside the
    # package root
    if ($self->is_file or ($self->is_symlink and -f $path)) {
        $self->{'_is_open_ok'} = 1;
        return 1;
    }
    $self->{'_is_open_ok'} = 0;
    confess("Attempt to open non-file (e.g. dir or pipe): $self");
}

sub _do_open {
    my ($self, $open_sub) = @_;
    my $path = $self->_collect_path($self);
    $self->_check_open($path);
    return $open_sub->($path);
}

=item open([LAYER])

Open and return a read handle to the file.  It optionally accepts the
LAYER argument.  If given it should specify the layer/discipline to
use when opening the file including the initial colon (e.g. ':raw').

Beyond regular issues with opening a file, this method may fail if:

=over

=item The object is not a file-like object (e.g. a directory or a named pipe).

=item If the object is dangling symlink or the path traverses a symlink
outside the package root.

=back

It is possible to test for these by using L</is_open_ok>.

=cut

sub open {
    my ($self, $layer) = @_;
    # Scoped autodie in here to avoid it overwriting our
    # method "open"
    $layer //= '';
    my $opener = sub {
        use autodie qw(open);
        open(my $fd, "<${layer}", $_[0]);
        return $fd;
    };
    return $self->_do_open($opener);
}

=item open_gz

Open a read handle to the file and decompress it as a GZip compressed
file.  This method may fail for the same reasons as L</open([LAYER])>.

The returned handle may be a pipe from an external process.

=cut

sub open_gz {
    my ($self) = @_;
    return $self->_do_open(\&Lintian::Util::open_gz);
}

### OVERLOADED OVERATORS ###

# overload apparently does not like the mk_ro_accessor, so use a level
# of indirection

sub _as_regex_ref {
    my ($self) = @_;
    my $name = $self->name;
    return qr{ \Q$name\E }xsm;
}

sub _as_string {
    my ($self) = @_;
    return $self->name;
}

sub _bool {
    # Always true (used in "if ($info->index('some/path')) {...}")
    return 1;
}

sub _bool_not {
    my ($self) = @_;
    return !$self->_bool;
}

sub _str_cmp {
    my ($self, $str, $swap) = @_;
    return $str cmp $self->name if $swap;
    return $self->name cmp $str;
}

sub _str_concat {
    my ($self, $str, $swap) = @_;
    return $str . $self->name if $swap;
    return $self->name . $str;
}

sub _str_eq {
    my ($self, $str) = @_;
    return $self->name eq $str;
}

sub _str_ne {
    my ($self, $str) = @_;
    return $self->name ne $str;
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


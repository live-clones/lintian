# files/symbolic-links -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::symbolic_links;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $BUILD_PATH_REGEX
  = Lintian::Data->new('files/build-path-regex',qr/~~~~~/,
    sub { return  qr/$_[0]/xsm;});

my $COMPRESS_FILE_EXTENSIONS
  = Lintian::Data->new('files/compressed-file-extensions',
    qr/\s++/,sub { return qr/\Q$_[0]\E/ });

# an OR (|) regex of all compressed extension
my $COMPRESS_FILE_EXTENSIONS_OR_ALL = sub { qr/(:?$_[0])/ }
  ->(
    join('|',
        map {$COMPRESS_FILE_EXTENSIONS->value($_) }
          $COMPRESS_FILE_EXTENSIONS->all));

# see tag compressed-symlink-with-wrong-ext
my $COMPRESSED_SYMLINK_POINTING_TO_COMPRESSED_REGEX
  = qr/\.($COMPRESS_FILE_EXTENSIONS_OR_ALL)\s*$/;

sub source {
    my ($self) = @_;

    for my $file ($self->processable->patched->sorted_list) {

        $self->tag('absolute-symbolic-link-target-in-source',
            $file->name, '->', $file->link)
          if $file->is_symlink && $file->link =~ m{^/}s;
    }

    return;
}

sub is_tmp_path {
    my ($path) = @_;
    if(    $path =~ m,^tmp/.,
        or $path =~ m,^(?:var|usr)/tmp/.,
        or $path =~ m,^/dev/shm/,) {
        return 1;
    }
    return 0;
}

sub tag_build_tree_path {
    my ($self, $path, $msg) = @_;
    foreach my $buildpath ($BUILD_PATH_REGEX->all) {
        my $regex = $BUILD_PATH_REGEX->value($buildpath);
        if ($path =~ m{$regex}xms) {
            $self->tag('symlink-target-in-build-tree', $msg);
        }
    }
    return;
}

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_symlink;

    my $mylink = $file->link;
    if ($mylink =~ s,//+,/,g) {
        $self->tag('symlink-has-double-slash', $file->name, $file->link);
    }
    if ($mylink =~ s,(.)/$,$1,) {
        $self->tag('symlink-ends-with-slash', $file->name, $file->link);
    }

    # determine top-level directory of file
    $file->name =~ m,^/?([^/]*),;
    my $filetop = $1;

    if ($mylink =~ m,^/([^/]*),) {
        my $flinkname = substr($mylink,1);
        # absolute link, including link to /
        # determine top-level directory of link
        my $linktop = $1;

        if ($self->type ne 'udeb' and $filetop eq $linktop) {
            # absolute links within one toplevel directory are _not_ ok!
            $self->tag('symlink-should-be-relative', $file->name, $file->link);
        }

        $self->tag_build_tree_path($flinkname,
            "symlink $file point to $mylink");

        if(is_tmp_path($flinkname)) {
            $self->tag('symlink-target-in-tmp', 'symlink', $file->name,
                "point to $mylink");
        }

        # Any other case is already definitely non-recursive
        $self->tag('symlink-is-self-recursive', $file->name, $file->link)
          if $mylink eq '/';

    } else {
        # relative link, we can assume from here that the link
        # starts nor ends with /

        my @filecomponents = split('/', $file->name);
        # chop off the name of the symlink
        pop @filecomponents;

        my @linkcomponents = split('/', $mylink);

        # handle `../' at beginning of $file->link
        my ($lastpop, $linkcomponent);
        while ($linkcomponent = shift @linkcomponents) {
            if ($linkcomponent eq '.') {
                $self->tag('symlink-contains-spurious-segments',
                    $file->name, $file->link)
                  unless $mylink eq '.';
                next;
            }
            last if $linkcomponent ne '..';
            if (@filecomponents) {
                $lastpop = pop @filecomponents;
            } else {
                $self->tag('symlink-has-too-many-up-segments',
                    $file->name, $file->link);
                goto NEXT_LINK;
            }
        }

        if (!defined $linkcomponent) {
            # After stripping all starting .. components, nothing left
            $self->tag('symlink-is-self-recursive', $file->name, $file->link);
        }

        # does the link go up and then down into the same
        # directory?  (lastpop indicates there was a backref
        # at all, no linkcomponent means the symlink doesn't
        # get up anymore)
        if (   defined $lastpop
            && defined $linkcomponent
            && $linkcomponent eq $lastpop) {
            $self->tag('lengthy-symlink', $file->name,  $file->link);
        }

        if ($#filecomponents == -1) {
            # we've reached the root directory
            if (   ($self->type ne 'udeb') && (!defined $linkcomponent)
                || ($filetop ne $linkcomponent)) {
                # relative link into other toplevel directory.
                # this hits a relative symbolic link in the root too.
                $self->tag('symlink-should-be-absolute', $file->name,
                    $file->link);
            }
        }

        # check additional segments for mistakes like `foo/../bar/'
        foreach (@linkcomponents) {
            if ($_ eq '..' || $_ eq '.') {
                $self->tag('symlink-contains-spurious-segments',
                    $file->name, $file->link);
                last;
            }
        }
    }
  NEXT_LINK:

    if ($file->link =~ $COMPRESSED_SYMLINK_POINTING_TO_COMPRESSED_REGEX) {
        # symlink is pointing to a compressed file

        # symlink has correct extension?
        unless ($file->name =~ m,\.$1\s*$,) {
            $self->tag('compressed-symlink-with-wrong-ext',
                $file->name,$file->link);
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

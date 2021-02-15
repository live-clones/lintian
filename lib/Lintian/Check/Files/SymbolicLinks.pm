# files/symbolic-links -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Files::SymbolicLinks;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SLASH => q{/};
const my $DOT => q{.};
const my $DOUBLE_DOT => q{..};
const my $VERTICAL_BAR => q{|};
const my $ARROW => q{->};

has COMPRESS_FILE_EXTENSIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/compressed-file-extensions',
            qr/\s++/,sub { return qr/\Q$_[0]\E/ });
    });

# an OR (|) regex of all compressed extension
has COMPRESS_FILE_EXTENSIONS_OR_ALL => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $text = join($VERTICAL_BAR,
            map {$self->COMPRESS_FILE_EXTENSIONS->value($_) }
              $self->COMPRESS_FILE_EXTENSIONS->all);

        return qr/$text/;
    });

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_symlink;

    # absolute links cannot be resolved
    if ($item->link =~ m{^/}) {

        # allow /dev/null link target for masked systemd service files
        $self->hint('absolute-symbolic-link-target-in-source',
            $item->name, $ARROW, $item->link)
          unless $item->link eq '/dev/null';
    }

    # some relative links cannot be resolved inside the source
    $self->hint('wayward-symbolic-link-target-in-source',
        $item->name, $ARROW, $item->link)
      unless defined $_->link_normalized || $item->link =~ m{^/};

    return;
}

sub is_tmp_path {
    my ($path) = @_;

    return 1
      if $path =~ m{^tmp/.}
      || $path =~ m{^(?:var|usr)/tmp/.}
      || $path =~ m{^/dev/shm/};

    return 0;
}

sub tag_build_tree_path {
    my ($self, $path, $msg) = @_;

    my $BUILD_PATH_REGEX
      = $self->profile->load_data('files/build-path-regex',qr/~~~~~/,
        sub { return  qr/$_[0]/xsm;});

    foreach my $buildpath ($BUILD_PATH_REGEX->all) {
        my $regex = $BUILD_PATH_REGEX->value($buildpath);
        if ($path =~ m{$regex}xms) {
            $self->hint('symlink-target-in-build-tree', $msg);
        }
    }
    return;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_symlink;

    my $mylink = $file->link;
    $self->hint('symlink-has-double-slash', $file->name, $file->link)
      if $mylink =~ s{//+}{/}g;

    $self->hint('symlink-ends-with-slash', $file->name, $file->link)
      if $mylink =~ s{(.)/$}{$1};

    # determine top-level directory of file
    $file->name =~ m{^/?([^/]*)};
    my $filetop = $1;

    if ($mylink =~ m{^/([^/]*)}) {
        my $flinkname = substr($mylink,1);
        # absolute link, including link to /
        # determine top-level directory of link
        my $linktop = $1;

        if ($self->processable->type ne 'udeb' and $filetop eq $linktop) {
            # absolute links within one toplevel directory are _not_ ok!
            $self->hint('absolute-symlink-in-top-level-folder',
                $file->name, $file->link);
        }

        $self->tag_build_tree_path($flinkname,
            "symlink $file point to $mylink");

        if(is_tmp_path($flinkname)) {
            $self->hint('symlink-target-in-tmp', 'symlink', $file->name,
                "point to $mylink");
        }

        # Any other case is already definitely non-recursive
        $self->hint('symlink-is-self-recursive', $file->name, $file->link)
          if $mylink eq $SLASH;

    } else {
        # relative link, we can assume from here that the link
        # starts nor ends with /

        my @filecomponents = split(m{/}, $file->name);
        # chop off the name of the symlink
        pop @filecomponents;

        my @linkcomponents = split(m{/}, $mylink);

        # handle `../' at beginning of $file->link
        my ($lastpop, $linkcomponent);
        while ($linkcomponent = shift @linkcomponents) {
            if ($linkcomponent eq $DOT) {
                $self->hint('symlink-contains-spurious-segments',
                    $file->name, $file->link)
                  unless $mylink eq $DOT;
                next;
            }
            last if $linkcomponent ne $DOUBLE_DOT;
            if (@filecomponents) {
                $lastpop = pop @filecomponents;
            } else {
                $self->hint('symlink-has-too-many-up-segments',
                    $file->name, $file->link);
                goto NEXT_LINK;
            }
        }

        if (!defined $linkcomponent) {
            # After stripping all starting .. components, nothing left
            $self->hint('symlink-is-self-recursive', $file->name, $file->link);
        }

        # does the link go up and then down into the same
        # directory?  (lastpop indicates there was a backref
        # at all, no linkcomponent means the symlink doesn't
        # get up anymore)
        if (   defined $lastpop
            && defined $linkcomponent
            && $linkcomponent eq $lastpop) {
            $self->hint('lengthy-symlink', $file->name,  $file->link);
        }

        unless (@filecomponents) {
            # we've reached the root directory
            if (   ($self->processable->type ne 'udeb')
                && (!defined $linkcomponent)
                || ($filetop ne $linkcomponent)) {
                # relative link into other toplevel directory.
                # this hits a relative symbolic link in the root too.
                $self->hint('relative-symlink', $file->name,$file->link);
            }
        }

        # check additional segments for mistakes like `foo/../bar/'
        foreach (@linkcomponents) {
            if ($_ eq $DOUBLE_DOT || $_ eq $DOT) {
                $self->hint('symlink-contains-spurious-segments',
                    $file->name, $file->link);
                last;
            }
        }
    }
  NEXT_LINK:

    my $regex = $self->COMPRESS_FILE_EXTENSIONS_OR_ALL;

    # see tag compressed-symlink-with-wrong-ext
    my $COMPRESSED_SYMLINK_POINTING_TO_COMPRESSED_REGEX= qr/\.($regex)\s*$/;

    if ($file->link =~ $COMPRESSED_SYMLINK_POINTING_TO_COMPRESSED_REGEX) {
        # symlink is pointing to a compressed file

        # symlink has correct extension?
        $self->hint('compressed-symlink-with-wrong-ext',
            $file->name,$file->link)
          unless $file->name =~ /\.$1\s*$/;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

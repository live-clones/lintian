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

# an OR (|) regex of all compressed extension
has COMPRESS_FILE_EXTENSIONS_OR_ALL => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $COMPRESS_FILE_EXTENSIONS
          = $self->data->load('files/compressed-file-extensions',qr/\s+/);

        my $text = join($VERTICAL_BAR,
            (map { quotemeta } $COMPRESS_FILE_EXTENSIONS->all));

        return qr/$text/;
    });

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_symlink;

    # absolute links cannot be resolved
    if ($item->link =~ m{^/}) {

        # allow /dev/null link target for masked systemd service files
        $self->pointed_hint('absolute-symbolic-link-target-in-source',
            $item->pointer, $item->link)
          unless $item->link eq '/dev/null';
    }

    # some relative links cannot be resolved inside the source
    $self->pointed_hint('wayward-symbolic-link-target-in-source',
        $item->pointer, $item->link)
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

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_symlink;

    my $mylink = $item->link;
    $self->pointed_hint('symlink-has-double-slash', $item->pointer,$item->link)
      if $mylink =~ s{//+}{/}g;

    $self->pointed_hint('symlink-ends-with-slash', $item->pointer, $item->link)
      if $mylink =~ s{(.)/$}{$1};

    # determine top-level directory of file
    $item->name =~ m{^/?([^/]*)};
    my $filetop = $1;

    if ($mylink =~ m{^/([^/]*)}) {
        my $flinkname = substr($mylink,1);
        # absolute link, including link to /
        # determine top-level directory of link
        my $linktop = $1;

        if ($self->processable->type ne 'udeb' and $filetop eq $linktop) {
            # absolute links within one toplevel directory are _not_ ok!
            $self->pointed_hint('absolute-symlink-in-top-level-folder',
                $item->pointer, $item->link);
        }

        my $BUILD_PATH_REGEX
          = $self->data->load('files/build-path-regex',qr/~~~~~/);

        for my $pattern ($BUILD_PATH_REGEX->all) {

            $self->pointed_hint('symlink-target-in-build-tree',
                $item->pointer, $mylink)
              if $flinkname =~ m{$pattern}xms;
        }

        $self->pointed_hint('symlink-target-in-tmp', $item->pointer,$mylink)
          if is_tmp_path($flinkname);

        # Any other case is already definitely non-recursive
        $self->pointed_hint('symlink-is-self-recursive', $item->pointer,
            $item->link)
          if $mylink eq $SLASH;

    } else {
        # relative link, we can assume from here that the link
        # starts nor ends with /

        my @filecomponents = split(m{/}, $item->name);
        # chop off the name of the symlink
        pop @filecomponents;

        my @linkcomponents = split(m{/}, $mylink);

        # handle `../' at beginning of $item->link
        my ($lastpop, $linkcomponent);
        while ($linkcomponent = shift @linkcomponents) {
            if ($linkcomponent eq $DOT) {
                $self->pointed_hint('symlink-contains-spurious-segments',
                    $item->pointer, $item->link)
                  unless $mylink eq $DOT;
                next;
            }
            last if $linkcomponent ne $DOUBLE_DOT;
            if (@filecomponents) {
                $lastpop = pop @filecomponents;
            } else {
                $self->pointed_hint('symlink-has-too-many-up-segments',
                    $item->pointer, $item->link);
                goto NEXT_LINK;
            }
        }

        if (!defined $linkcomponent) {
            # After stripping all starting .. components, nothing left
            $self->pointed_hint('symlink-is-self-recursive', $item->pointer,
                $item->link);
        }

        # does the link go up and then down into the same
        # directory?  (lastpop indicates there was a backref
        # at all, no linkcomponent means the symlink doesn't
        # get up anymore)
        if (   defined $lastpop
            && defined $linkcomponent
            && $linkcomponent eq $lastpop) {
            $self->pointed_hint('lengthy-symlink', $item->pointer,$item->link);
        }

        unless (@filecomponents) {
            # we've reached the root directory
            if (   ($self->processable->type ne 'udeb')
                && (!defined $linkcomponent)
                || ($filetop ne $linkcomponent)) {

                # relative link into other toplevel directory.
                # this hits a relative symbolic link in the root too.
                $self->pointed_hint('relative-symlink', $item->pointer,
                    $item->link);
            }
        }

        # check additional segments for mistakes like `foo/../bar/'
        foreach (@linkcomponents) {
            if ($_ eq $DOUBLE_DOT || $_ eq $DOT) {
                $self->pointed_hint('symlink-contains-spurious-segments',
                    $item->pointer, $item->link);
                last;
            }
        }
    }
  NEXT_LINK:

    my $pattern = $self->COMPRESS_FILE_EXTENSIONS_OR_ALL;

    # symlink pointing to a compressed file
    if ($item->link =~ qr{ [.] ($pattern) \s* $}x) {

        my $extension = $1;

        # symlink has correct extension?
        $self->pointed_hint('compressed-symlink-with-wrong-ext',
            $item->pointer, $item->link)
          unless $item->name =~ qr{[.]$extension\s*$};
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# documentation -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Check::Documentation;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(encode_utf8);

const my $VERTICAL_BAR => q{|};

# 276 is 255 bytes (maximal length for a filename) plus gzip overhead
const my $MAXIMUM_EMPTY_GZIP_SIZE => 276;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# a list of regex for detecting non documentation files checked against basename (xi)
my @NOT_DOCUMENTATION_FILE_REGEXES = qw{
  ^dependency_links[.]txt$
  ^entry_points[.]txt$
  ^requires[.]txt$
  ^top_level[.]txt$
  ^requirements[.]txt$
  ^namespace_packages[.]txt$
  ^bindep[.]txt$
  ^version[.]txt$
  ^robots[.]txt$
  ^cmakelists[.]txt$
}

# a list of regex for detecting documentation file checked against basename (xi)
my @DOCUMENTATION_FILE_REGEXES = qw{
  [.]docx?$
  [.]html?$
  [.]info$
  [.]latex$
  [.]markdown$
  [.]md$
  [.]odt$
  [.]pdf$
  [.]readme$
  [.]rmd$
  [.]rst$
  [.]rtf$
  [.]tex$
  [.]txt$
  ^code[-_]of[-_]conduct$
  ^contribut(?:e|ing)$
  ^copyright$
  ^licen[sc]es?$
  ^howto$
  ^patents?$
  ^readme(?:[.]?first|[.]1st|[.]debian|[.]source)?$
  ^todos?$
};

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
    }
);

sub visit_installed_files {
    my ($self, $item) = @_;

    my $ppkg = quotemeta($self->processable->name);

    if (   $self->processable->type eq 'udeb'
        && $item->name =~ m{^usr/share/(?:doc|info)/\S}) {

        $self->pointed_hint('udeb-contains-documentation-file',$item->pointer);
        return;
    }

    $self->pointed_hint('package-contains-info-dir-file', $item->pointer)
      if $item->name =~ m{^ usr/share/info/dir (?:[.]old)? (?:[.]gz)? $}x;

    # doxygen md5sum
    $self->pointed_hint('useless-autogenerated-doxygen-file', $item->pointer)
      if $item->name =~ m{^ usr/share/doc/ $ppkg / [^/]+ / .+ [.]md5$ }sx
      && $item->parent_dir->child('doxygen.png');

    my $regex = $self->COMPRESS_FILE_EXTENSIONS_OR_ALL;

    # doxygen compressed map
    $self->pointed_hint('compressed-documentation', $item->pointer)
      if $item->name
      =~ m{^ usr/share/doc/ (?:.+/)? (?:doxygen|html) / .* [.]map [.] $regex }sx;

    if ($item->is_file
        && any { $item->basename =~ m{$_}xi } @DOCUMENTATION_FILE_REGEXES
        && any { $item->basename !~ m{$_}xi } @NOT_DOCUMENTATION_FILE_REGEXES) {

        $self->pointed_hint(
            'package-contains-documentation-outside-usr-share-doc',
            $item->pointer)
          unless $item->name =~ m{^etc/}
          || $item->name =~ m{^usr/share/(?:doc|help)/}
          # see Bug#981268
          # usr/lib/python3/dist-packages/*.dist-info/entry_points.txt
          || $item->name =~ m{^ usr/lib/python3/dist-packages/
                              .+ [.] dist-info/entry_points.txt $}sx
          # No need for dh-r packages to automatically
          # create overrides if we just allow them all to
          # begin with.
          || $item->dirname =~ 'usr/lib/R/site-library/'
          # SNMP MIB files, see Bug#971427
          || $item->dirname eq 'usr/share/snmp/mibs/'
          # see Bug#904852
          || $item->dirname =~ m{templates?(?:[.]d)?/}
          || ( $item->basename =~ m{^README}xi
            && $item->bytes =~ m{this directory}xi)
          # see Bug#1009679, not documentation, just an unlucky suffix
          || $item->name =~ m{^var/lib/ocaml/lintian/.+[.]info$}
          # see Bug#970275
          || $item->name =~ m{^usr/share/gtk-doc/html/.+[.]html?$};
    }

    if ($item->name =~ m{^usr/share/doc/\S}) {

        # file not owned by root?
        unless ($item->identity eq 'root/root' || $item->identity eq '0/0') {
            $self->pointed_hint('bad-owner-for-doc-file', $item->pointer,
                $item->identity,'!= root/root (or 0/0)');
        }

        # executable in /usr/share/doc ?
        if (   $item->is_file
            && $item->name !~ m{^usr/share/doc/(?:[^/]+/)?examples/}
            && $item->is_executable) {

            if ($item->is_script) {
                $self->pointed_hint('script-in-usr-share-doc', $item->pointer);
            } else {
                $self->pointed_hint('executable-in-usr-share-doc',
                    $item->pointer,(sprintf '%04o', $item->operm));
            }
        }

        # zero byte file in /usr/share/doc/
        if ($item->is_regular_file and $item->size == 0) {
            # Exceptions: examples may contain empty files for various
            # reasons, Doxygen generates empty *.map files, and Python
            # uses __init__.py to mark module directories.
            unless ($item->name =~ m{^usr/share/doc/(?:[^/]+/)?examples/}
                || $item->name
                =~ m{^usr/share/doc/(?:.+/)?(?:doxygen|html)/.*[.]map$}s
                || $item->name=~ m{^usr/share/doc/(?:.+/)?__init__[.]py$}s){

                $self->pointed_hint('zero-byte-file-in-doc-directory',
                    $item->pointer);
            }
        }

        if (   $item->name =~ / [.]gz $/msx
            && $item->is_regular_file
            && $item->size <= $MAXIMUM_EMPTY_GZIP_SIZE
            && $item->file_type =~ / gzip \s compressed /msx) {

            open(my $fd, '<:gzip', $item->unpacked_path)
              or die encode_utf8('Cannot open ' . $item->unpacked_path);

            my $f = <$fd>;
            close($fd);

            unless (defined $f and length $f) {
                $self->pointed_hint('zero-byte-file-in-doc-directory',
                    $item->pointer);
            }
        }
    }

    # file directly in /usr/share/doc ?
    $self->pointed_hint('file-directly-in-usr-share-doc', $item->pointer)
      if $item->is_file
      && $item->name =~ m{^ usr/share/doc/ [^/]+ $}x;

    # contains an INSTALL file?
    $self->pointed_hint('package-contains-upstream-installation-documentation',
        $item->pointer)
      if $item->name =~ m{^ usr/share/doc/ $ppkg / INSTALL (?: [.] .+ )* $}sx;

    # contains a README for another distribution/platform?
    $self->pointed_hint('package-contains-readme-for-other-platform-or-distro',
        $item->pointer)
      if $item->name =~ m{^usr/share/doc/$ppkg/readme[.]
                             (?:apple|aix|atari|be|beos|bsd|bsdi
                               |cygwin|darwin|irix|gentoo|freebsd|mac|macos
                               |macosx|netbsd|openbsd|osf|redhat|sco|sgi
                               |solaris|suse|sun|vms|win32|win9x|windows
                             )(?:[.]txt)?(?:[.]gz)?$}xi;

    # contains a compressed version of objects.inv in
    # sphinx-generated documentation?
    $self->pointed_hint('compressed-documentation', $item->pointer)
      if $item->name
      =~ m{^ usr/share/doc/ $ppkg / (?: [^/]+ / )+ objects [.]inv [.]gz $}x
      && $item->file_type =~ m{gzip compressed};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

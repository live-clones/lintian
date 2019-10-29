# files/documentation -- lintian check script -*- perl -*-

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

package Lintian::files::documentation;

use strict;
use warnings;
use autodie;

use Moo;

with('Lintian::Check');

my $DOCUMENTATION_FILE_REGEX
  = Lintian::Data->new('files/documentation-file-regex',
    qr/~~~~~/,sub { return  qr/$_[0]/xi;});

has ppkg => (is => 'rwp');

sub setup {
    my ($self) = @_;

    $self->_set_ppkg(quotemeta($self->package));

    return;
}

sub files {
    my ($self, $file) = @_;

    if ($self->type eq 'udeb') {
        if ($file->name =~ m,^usr/share/(?:doc|info)/\S,) {

            $self->tag('udeb-contains-documentation-file', $file->name);
            return;
        }
    }

    if ($file->name =~ m,^usr/share/info/dir(?:\.old)?(?:\.gz)?$,) {
        $self->tag('package-contains-info-dir-file', $file->name);
    }

    my $ppkg = $self->ppkg;

    if(    $file->is_file
        && $file->name !~ m,^etc/,
        && $file->name !~ m,^usr/share/(?:doc|help)/,
        && $self->processable->pkg_src ne 'lintian') {

        foreach my $taboo ($DOCUMENTATION_FILE_REGEX->all) {

            my $regex = $DOCUMENTATION_FILE_REGEX->value($taboo);

            if($file->basename =~ m{$regex}xi) {

                # No need for dh-r packages to automatically
                # create overrides if we just allow them all to
                # begin with.
                next
                  if $file->dirname =~ m{^usr/lib/R/site-library/};

                # see #904852
                next
                  if $file->dirname =~ m{templates?(?:\.d)?/};

                next
                  if $file->basename =~ m{^README}xi
                  and $file->file_contents =~ m{this directory}xi;

                $self->tag(
                    'package-contains-documentation-outside-usr-share-doc',
                    $file->name);

                last;
            }
        }
    }

    if ($file->name =~ m,^usr/share/doc/\S,) {

        # file not owned by root?
        if ($file->identity ne 'root/root') {
            $self->tag('bad-owner-for-doc-file', $file->name, $file->identity,
                '!= root/root');
        }

        # executable in /usr/share/doc ?
        if (    $file->is_file
            and $file->name !~ m,^usr/share/doc/(?:[^/]+/)?examples/,
            and ($file->operm & 0111)) {
            if ($self->info->is_script($file->name)) {
                $self->tag('script-in-usr-share-doc', $file->name);
            } else {
                $self->tag('executable-in-usr-share-doc', $file->name,
                    (sprintf '%04o', $file->operm));
            }
        }

        # zero byte file in /usr/share/doc/
        if ($file->is_regular_file and $file->size == 0) {
            # Exceptions: examples may contain empty files for various
            # reasons, Doxygen generates empty *.map files, and Python
            # uses __init__.py to mark module directories.
            unless ($file->name =~ m,^usr/share/doc/(?:[^/]+/)?examples/,
                or $file->name
                =~ m,^usr/share/doc/(?:.+/)?(?:doxygen|html)/.*\.map$,
                or $file->name=~ m,^usr/share/doc/(?:.+/)?__init__\.py$,){

                $self->tag('zero-byte-file-in-doc-directory', $file->name);
            }
        }

        # gzipped zero byte files:
        # 276 is 255 bytes (maximal length for a filename)
        # + gzip overhead
        if (    $file->name =~ m,.gz$,
            and $file->is_regular_file
            and $file->size <= 276
            and $file->file_info =~ m/gzip compressed/) {
            my $fd = $file->open_gz;
            my $f = <$fd>;
            close($fd);
            unless (defined $f and length $f) {
                $self->tag('zero-byte-file-in-doc-directory', $file->name);
            }
        }
    }

    # file directly in /usr/share/doc ?
    if (    $file->is_file
        and $file->name =~ m,^usr/share/doc/[^/]+$,){
        $self->tag('file-directly-in-usr-share-doc', $file->name);
    }

    # contains an INSTALL file?
    if ($file->name =~ m,^usr/share/doc/$ppkg/INSTALL(?:\..+)*$,){
        $self->tag('package-contains-upstream-installation-documentation',
            $file->name);
    }

    # contains a README for another distribution/platform?
    if (
        $file->name =~ m,^usr/share/doc/$ppkg/readme\.
                             (?:apple|aix|atari|be|beos|bsd|bsdi
                               |cygwin|darwin|irix|gentoo|freebsd|mac|macos
                               |macosx|netbsd|openbsd|osf|redhat|sco|sgi
                               |solaris|suse|sun|vms|win32|win9x|windows
                             )(?:\.txt)?(?:\.gz)?$,xi
    ) {
        $self->tag('package-contains-readme-for-other-platform-or-distro',
            $file->name);
    }

    # contains a compressed version of objects.inv in
    # sphinx-generated documentation?
    if (    $file->name=~ m,^usr/share/doc/$ppkg/(?:[^/]+/)+objects\.inv\.gz$,
        and $file->file_info =~ m/gzip compressed/) {
        $self->tag('file-should-not-be-compressed', $file->name);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

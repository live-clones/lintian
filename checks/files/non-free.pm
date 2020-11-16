# files/non-free -- lintian check script -*- perl -*-

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

package Lintian::files::non_free;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# A list of known non-free flash executables
my @flash_nonfree = (
    qr<(?i)dewplayer(?:-\w+)?\.swf$>,
    qr<(?i)(?:mp3|flv)player\.swf$>,
    # Situation needs to be clarified:
    #    qr,(?i)multipleUpload\.swf$,
    #    qr,(?i)xspf_jukebox\.swf$,
);

sub visit_installed_files {
    my ($self, $file) = @_;

    # only look at packages with undeclared non-free content
    return
      if $self->processable->is_non_free;

    # non-free .swf files
    foreach my $flash (@flash_nonfree) {
        if ($file->name =~ m,/$flash,) {
            $self->hint('non-free-flash', $file->name);
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

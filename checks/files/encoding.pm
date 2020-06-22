# files/encoding -- lintian check script -*- perl -*-

# Copyright © 2020 Felix Lechner
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

package Lintian::files::encoding;

use v5.20;
use warnings;
use utf8;
use autodie;

use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Unicode::UTF8 qw(valid_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub files_patched {
    my ($self, $file) = @_;

    return
      unless $file->name =~ /^debian/;

    return
      unless $file->file_info =~ /text$/;

    $self->tag('national-encoding', $file->name)
      unless $file->is_valid_utf8;

    return;
}

sub files_control {
    my ($self, $file) = @_;

    return
      unless $file->is_script;

    $self->tag('national-encoding', 'CONTROL-FILE:' . $file->name)
      unless $file->is_valid_utf8;

    return;
}

sub files_installed {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    # this checks debs; most other nat'l encoding tags are for source
    # Bug#796170 also suggests limiting paths and including gzip files

    # return
    #   unless $file->name =~ m{^(?:usr/)?s?bin/}
    #   || $file->name =~ m{^usr/games/}
    #   || $file->name =~ m{\.(?:p[myl]|php|rb|tcl|sh|txt)(?:\.gz)?$}
    #   || $file->name =~ m{^usr/share/doc};

    if ($file->file_info =~ /text$/) {

        $self->tag('national-encoding', $file->name)
          unless $file->is_valid_utf8;
    }

    # for man pages also look at compressed files
    if (   $file->name =~ m{^usr/share/man/}
        && $file->file_info =~ /gzip compressed/) {

        my $bytes;

        my $path = $file->unpacked_path;
        gunzip($path => \$bytes)
          or die "gunzip $path failed: $GunzipError";

        $self->tag('national-encoding', $file->name)
          unless valid_utf8($bytes);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

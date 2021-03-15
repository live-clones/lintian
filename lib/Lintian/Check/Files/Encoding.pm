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

package Lintian::Check::Files::Encoding;

use v5.20;
use warnings;
use utf8;

use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Unicode::UTF8 qw(valid_utf8 encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{^debian/};

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /text$/;

    if ($item->name =~ m{^debian/patches/}) {

        my $bytes = $item->bytes;
        return
          unless length $bytes;

        my ($header)= split(/^---/m, $bytes, 2);

        $self->hint('national-encoding', 'DEP-3 header ' . $item->name)
          unless valid_utf8($header);

    } else {
        $self->hint('national-encoding', $item->name)
          unless $item->is_valid_utf8;
    }

    return;
}

sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /text$/ || $item->is_script;

    $self->hint('national-encoding', 'DEBIAN/' . $item->name)
      unless $item->is_valid_utf8;

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # this checks debs; most other nat'l encoding tags are for source
    # Bug#796170 also suggests limiting paths and including gzip files

    # return
    #   unless $item->name =~ m{^(?:usr/)?s?bin/}
    #   || $item->name =~ m{^usr/games/}
    #   || $item->name =~ m{\.(?:p[myl]|php|rb|tcl|sh|txt)(?:\.gz)?$}
    #   || $item->name =~ m{^usr/share/doc};

    if ($item->file_info =~ /text$/) {

        $self->hint('national-encoding', $item->name)
          unless $item->is_valid_utf8;
    }

    # for man pages also look at compressed files
    if (   $item->name =~ m{^usr/share/man/}
        && $item->file_info =~ /gzip compressed/) {

        my $bytes;

        my $path = $item->unpacked_path;
        gunzip($path => \$bytes)
          or die encode_utf8("gunzip $path failed: $GunzipError");

        $self->hint('national-encoding', $item->name)
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

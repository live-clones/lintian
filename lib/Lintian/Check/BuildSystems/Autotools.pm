# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIES
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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

package Lintian::Check::BuildSystems::Autotools;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    if (   $item->name =~ /configure\.(in|ac)$/
        && $item->is_open_ok) {

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            next
              if $line =~ m{^ \s* dnl }x;

            if ($line
                =~ m{ (AC_PATH_PROG) \s* [(] [^,]+ , \s* \[? pkg-config \]? \s* , }x
            ){

                my $macro = $1;
                $self->pointed_hint(
                    'autotools-pkg-config-macro-not-cross-compilation-safe',
                    $item->pointer($position), $macro);
            }

        } continue {
            ++$position;
        }

        close $fd;
    }

    # Tests of autotools files are a special case.  Ignore
    # debian/config.cache as anyone doing that probably knows what
    # they're doing and is using it as part of the build.
    $self->pointed_hint('configure-generated-file-in-source', $item->pointer)
      if $item->basename =~ m{\A config.(?:cache|log|status) \Z}xsm
      && $item->name !~ m{^ debian/ }sx;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

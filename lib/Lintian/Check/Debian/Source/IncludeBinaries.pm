# debian/source/include-binaries -- lintian check script -*- perl -*-

# Copyright © 2019 Felix Lechner
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

package Lintian::Check::Debian::Source::IncludeBinaries;

use v5.20;
use warnings;
use utf8;

use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $sourcedir= $self->processable->patched->resolve_path('debian/source/');
    return
      unless $sourcedir;

    my $file = $sourcedir->child('include-binaries');
    return
      unless $file && $file->is_open_ok;

    my @lines = path($file->unpacked_path)->lines({ chomp => 1 });

    # format described in dpkg-source (1)
    my $position = 1;
    for my $line (@lines) {

        next
          if $line =~ /^\s*$/;

        next
          if $line =~ /^#/;

        # trim both ends
        $line =~ s/^\s+|\s+$//g;

        $self->hint('unused-entry-in-debian-source-include-binaries',
            $line, "(line $position)")
          unless $self->processable->patched->resolve_path($line);

    } continue {
        ++$position;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

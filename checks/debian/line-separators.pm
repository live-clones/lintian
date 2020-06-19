# debian/line-separators -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright © 1999 Joey Hess
# Copyright © 2000 Sean 'Shaleh' Perry
# Copyright © 2002 Josip Rodin
# Copyright © 2007 Russ Allbery
# Copyright © 2013-2018 Bastien ROUCARIÈS
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::debian::line_separators;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# files in ./debian to check for line terminators
my @CANDIDATES = qw(control changelog);

sub source {
    my ($self) = @_;

    my @files= grep { defined }
      map { $self->processable->patched->resolve_path("debian/$_") }
      @CANDIDATES;

    for my $file (@files) {
        my $bytes = $file->bytes;
        next
          unless length $bytes;

        $self->tag('carriage-return-line-feed', $file->name)
          if $bytes =~ m{\r\n\Z}m;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

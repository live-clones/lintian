# debian/lintian-overrides -- lintian check script -*- perl -*-

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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Debian::LintianOverrides;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    my $ppkg = quotemeta($self->processable->name);

    # misplaced overrides
    if ($item->name =~ m{^usr/share/doc/$ppkg/override\.[lL]intian(?:\.gz)?$}
        || $item->name =~ m{^usr/share/lintian/overrides/$ppkg/.+}) {

        $self->pointed_hint('override-file-in-wrong-location', $item->pointer);

    } elsif ($item->name =~ m{^usr/share/lintian/overrides/(.+)/.+$}) {

        my $expected = $1;

        $self->pointed_hint('override-file-in-wrong-package',
            $item->pointer, $expected)
          unless $self->processable->name eq $expected;
    }

    $self->pointed_hint('old-source-override-location', $item->pointer)
      if $item->name eq 'debian/source.lintian-overrides';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

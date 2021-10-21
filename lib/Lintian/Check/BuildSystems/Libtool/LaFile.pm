# build-systems/libtool/la-file -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::BuildSystems::Libtool::LaFile;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SLASH => q{/};

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      if $item->name !~ /[.]la$/ || length $item->link;

    my @lines = split(/\n/, $item->decoded_utf8);

    my $position = 1;
    for my $line (@lines) {

        if ($line =~ /^ libdir=' (.+) ' $/x) {

            my $own_location = $1;
            $own_location =~ s{^/+}{};
            $own_location =~ s{/*$}{/};

            # python-central is a special case since the
            # libraries are moved at install time.
            next
              if $own_location
              =~ m{^ usr/lib/python [\d.]+ / (?:site|dist)-packages / }x
              && $item->dirname =~ m{^ usr/share/pyshared/ }x;

            $self->hint(
                'incorrect-libdir-in-la-file', $item->name,
                "(line $position)",
                "$own_location != " . $item->dirname
            ) unless $own_location eq $item->dirname;

        }

        if ($line =~ /^ dependency_libs=' (.+) ' $/x){

            my $prerequisites = $1;

            $self->hint(
                'non-empty-dependency_libs-in-la-file',
                $item, "(line $position)",
                $prerequisites
            );
        }

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

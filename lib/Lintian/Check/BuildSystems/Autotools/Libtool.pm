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

package Lintian::Check::BuildSystems::Autotools::Libtool;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $ACCEPTABLE_LIBTOOL_MAJOR => 5;
const my $ACCEPTABLE_LIBTOOL_MINOR => 2;
const my $ACCEPTABLE_LIBTOOL_DEBIAN => 2;

# Check if the package build-depends on autotools-dev, automake,
# or libtool.
my $LIBTOOL = Lintian::Relation->new->load('libtool | dh-autoreconf');
has libtool_in_build_depends => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->processable->relation('Build-Depends-All')
          ->satisfies($LIBTOOL);
    }
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    $self->pointed_hint('ancient-libtool', $item->pointer)
      if $item->basename eq 'ltconfig'
      && $item->name !~ m{^ debian/ }sx
      && !$self->libtool_in_build_depends;

    if (   $item->basename eq 'ltmain.sh'
        && $item->name !~ m{^ debian/ }sx
        && !$self->libtool_in_build_depends) {

        if ($item->bytes =~ /^VERSION=[\"\']?(1\.(\d)\.(\d+)(?:-(\d))?)/m) {
            my ($version, $major, $minor, $debian)=($1, $2, $3, $4);

            $debian //= 0;

            $self->pointed_hint('ancient-libtool', $item->pointer, $version)
              if $major < $ACCEPTABLE_LIBTOOL_MAJOR
              || (
                $major == $ACCEPTABLE_LIBTOOL_MAJOR
                && (
                    $minor < $ACCEPTABLE_LIBTOOL_MINOR
                    || (   $minor == $ACCEPTABLE_LIBTOOL_MINOR
                        && $debian < $ACCEPTABLE_LIBTOOL_DEBIAN)
                )
              );
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

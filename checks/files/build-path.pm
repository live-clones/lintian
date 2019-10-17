# files/build-path -- lintian check script -*- perl -*-

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

package Lintian::files::build_path;

use strict;
use warnings;
use autodie;

use Moo;

with('Lintian::Check');

my $BUILD_PATH_REGEX
  = Lintian::Data->new('files/build-path-regex',qr/~~~~~/,
    sub { return  qr/$_[0]/xsm;});

sub files {
    my ($self, $file) = @_;

    # build directory
    unless ($self->source eq 'sbuild' || $self->source eq 'pbuilder') {

        foreach my $buildpath ($BUILD_PATH_REGEX->all) {
            my $regex = $BUILD_PATH_REGEX->value($buildpath);
            if ($file->name =~ m{$regex}xms) {

                $self->tag('dir-or-file-in-build-tree', $file->name);
            }
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
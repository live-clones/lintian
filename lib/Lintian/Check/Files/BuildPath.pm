# files/build-path -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::BuildPath;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has BUILD_PATH_REGEX => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/build-path-regex',qr/~~~~~/,
            sub { return  qr/$_[0]/xsm;});
    });

sub visit_installed_files {
    my ($self, $file) = @_;

    # build directory
    unless ($self->processable->source_name eq 'sbuild'
        || $self->processable->source_name eq 'pbuilder') {

        foreach my $buildpath ($self->BUILD_PATH_REGEX->all) {
            my $regex = $self->BUILD_PATH_REGEX->value($buildpath);
            if ($file->name =~ m{$regex}xms) {

                $self->hint('dir-or-file-in-build-tree', $file->name);
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

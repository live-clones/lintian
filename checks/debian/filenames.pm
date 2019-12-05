# debian/filenames -- lintian check script -*- perl -*-

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

package Lintian::debian::filenames;

use strict;
use warnings;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    # names are different in installation packages (see #429510)
    # README and TODO may be handled differently

    my @often_misnamed = ({ correct => 'NEWS', problematic => 'NEWS.Debian' });

    for my $relative (@often_misnamed) {

        my $correct = 'debian/' . $relative->{correct};
        my $problematic = 'debian/' . $relative->{problematic};

        if ($self->processable->index_resolved_path($problematic)) {

            if ($self->processable->index_resolved_path($correct)) {
                $self->tag('duplicate-packaging-file',
                    "$problematic -> $correct");

            } else {
                $self->tag(
                    'incorrect-packaging-filename',
                    "$problematic -> $correct"
                );
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

# debian/filenames -- lintian check script -*- perl -*-

# Copyright (C) 2019 Felix Lechner
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

package Lintian::Check::Debian::Filenames;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    # names are different in installation packages (see #429510)
    # README and TODO may be handled differently

    my @often_misnamed = (
        { correct => 'NEWS', problematic => 'NEWS.Debian' },
        { correct => 'NEWS', problematic => 'NEWS.debian' },
        { correct => 'TODO', problematic => 'TODO.Debian' },
        { correct => 'TODO', problematic => 'TODO.debian' }
    );

    for my $relative (@often_misnamed) {

        my $problematic_item = $self->processable->patched->resolve_path(
            'debian/' . $relative->{problematic});

        next
          unless defined $problematic_item;

        my $correct_name = 'debian/' . $relative->{correct};
        if ($self->processable->patched->resolve_path($correct_name)) {

            $self->pointed_hint('duplicate-packaging-file',
                $problematic_item->pointer,
                'better:', $correct_name);

        } else {
            $self->pointed_hint(
                'incorrect-packaging-filename',
                $problematic_item->pointer,
                'better:', $correct_name
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

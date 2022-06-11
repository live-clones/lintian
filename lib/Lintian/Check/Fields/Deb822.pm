# fields/deb822 -- lintian check script -*- perl -*-
#
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Check::Fields::Deb822;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Syntax::Keyword::Try;

use Lintian::Deb822;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SECTION => q{§};

my @SOURCE_DEB822 = qw(debian/control);

sub source {
    my ($self) = @_;

    for my $location (@SOURCE_DEB822) {

        my $item = $self->processable->patched->resolve_path($location);
        return
          unless defined $item;

        my $deb822 = Lintian::Deb822->new;

        my @sections;
        try {
            @sections = $deb822->read_file($item->unpacked_path)

        } catch {
            next;
        }

        my $count = 1;
        for my $section (@sections) {

            for my $field_name ($section->names) {

                my $field_value = $section->value($field_name);

                my $position = $section->position($field_name);
                my $pointer = $item->pointer($position);

                $self->pointed_hint('trimmed-deb822-field', $pointer,
                    $SECTION . $count,
                    $field_name, $field_value);
            }

        } continue {
            $count++;
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

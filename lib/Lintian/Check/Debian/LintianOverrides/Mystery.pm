# debian/lintian-overrides/mystery -- lintian check script -*- perl -*-

# Copyright (C) 2021 Felix Lechner
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

package Lintian::Check::Debian::LintianOverrides::Mystery;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $ARROW => q{=>};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    for my $override (@{$self->processable->overrides}) {

        my $override_item = $self->processable->override_file;
        my $pointer = $override_item->pointer($override->position);

        my $mystery_name = $override->tag_name;
        my $current_name = $self->profile->get_current_name($mystery_name);

        $self->pointed_hint('alien-tag', $pointer, $mystery_name)
          if !length $current_name;

        $self->pointed_hint('renamed-tag', $pointer, $mystery_name, $ARROW,
            $current_name)
          if length $current_name
          && $current_name ne $mystery_name;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

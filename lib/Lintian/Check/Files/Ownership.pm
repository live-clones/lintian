# files/ownership -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::Ownership;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SLASH => q{/};

const my $MAXIMUM_LOW_RESERVED => 99;
const my $MAXIMUM_HIGH_RESERVED => 64_999;
const my $MINIMUM_HIGH_RESERVED => 60_000;
const my $NOBODY => 65_534;

sub visit_installed_files {
    my ($self, $file) = @_;

    $self->hint('wrong-file-owner-uid-or-gid', $file->name,
        $file->uid . $SLASH . $file->gid)
      if out_of_bounds($file->uid)
      || out_of_bounds($file->gid);

    return;
}

sub out_of_bounds {
    my ($id) = @_;

    return 0
      if $id <= $MAXIMUM_LOW_RESERVED;

    return 0
      if $id == $NOBODY;

    return 0
      if $id >= $MINIMUM_HIGH_RESERVED
      && $id <= $MAXIMUM_HIGH_RESERVED;

    return 1;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# fields/package -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::fields::package;

use strict;
use warnings;
use autodie;

use Lintian::Tags qw(tag);
use Lintian::Util qw($PKGNAME_REGEX);

sub binary {
    my (undef, undef, $info, undef, undef) = @_;

    my $name = $info->unfolded_field('package');

    unless (defined $name) {
        tag 'no-package-name';
        return;
    }

    tag 'bad-package-name'
      unless $name =~ /^$PKGNAME_REGEX$/i;

    tag 'package-not-lowercase'
      if $name =~ /[A-Z]/;

    tag 'unusual-documentation-package-name'
      if $name =~ /-docs$/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# vcs/git-buildpackage-conf -- lintian check script -*- perl -*-

# Copyright (C) 2025 Otto Kekäläinen
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

package Lintian::Check::VersionControl::GitBuildpackage;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Not a requirement for git-buildpackage, but if a configuration exists,
# then highly likely package is maintained in version control with git-buildpackage
my @KNOWN_LOCATIONS = qw(
  debian/gbp.conf
);

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless any { $item->name eq $_ } @KNOWN_LOCATIONS;

    # If we find a gbp.conf file, mark this package as using git-buildpackage
    $self->pointed_hint('uses-gbp-conf', $item->pointer);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

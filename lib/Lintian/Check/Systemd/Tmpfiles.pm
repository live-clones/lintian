# systemd -- lintian check script -*- perl -*-
#
# Copyright © 2013 Michael Stapelberg
# Copyright © 2016-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
#
# based on the apache2 checks file by:
# Copyright © 2012 Arno Töll
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

package Lintian::Check::Systemd::Tmpfiles;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    $self->hint('systemd-tmpfile-in-var-run', $item->name)
      if $item->name =~ m{^ usr/lib/tmpfiles[.]d/ .* [.]conf $}sx
      && $item->decoded_utf8 =~ m{^ d \s+ /var/run/ }msx;

    $self->hint('misplaced-systemd-tmpfiles', $item->name)
      if $item->name =~ m{^ etc/tmpfiles[.]d/ .* [.]conf $}sx
      && $item->is_file;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

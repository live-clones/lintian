# cron -- lintian check script -*- perl -*-

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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Cron;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $READ_WRITE_PERMISSIONS => oct(644);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{^ etc/cron }x;

    # /etc/cron.daily, etc.
    # NB: cron ships ".placeholder" files, which shouldn't be run.
    $self->pointed_hint('run-parts-cron-filename-contains-illegal-chars',
        $item->pointer)
      if $item->name
      =~ m{^ etc/cron[.] (?: daily | hourly | monthly | weekly |d ) / [^.] .* [+.] }x;

    # /etc/cron.d
    # NB: cron ships ".placeholder" files in etc/cron.d,
    # which we shouldn't tag.
    $self->pointed_hint('bad-permissions-for-etc-cron.d-script',
        $item->pointer,
        sprintf('%04o != %04o', $item->operm, $READ_WRITE_PERMISSIONS))
      if $item->name =~ m{ ^ etc/cron\.d/ [^.] }msx
      && $item->operm != $READ_WRITE_PERMISSIONS;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# files/init -- lintian check script -*- perl -*-

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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Files::Init;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(none);

const my $NOT_EQUAL => q{!=};

const my $EXECUTABLE_PERMISSIONS => oct(755);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    # /etc/init
    $self->pointed_hint('package-installs-deprecated-upstart-configuration',
        $item->pointer)
      if $item->name =~ m{^etc/init/\S};

    # /etc/init.d
    $self->pointed_hint(
        'non-standard-file-permissions-for-etc-init.d-script',
        $item->pointer,
        $item->octal_permissions,
        $NOT_EQUAL,
        sprintf('%04o', $EXECUTABLE_PERMISSIONS)
      )
      if $item->name =~ m{^etc/init\.d/\S}
      && $item->name !~ m{^etc/init\.d/(?:README|skeleton)$}
      && $item->operm != $EXECUTABLE_PERMISSIONS
      && $item->is_file;

    # /etc/rc.d && /etc/rc?.d
    $self->pointed_hint('package-installs-into-etc-rc.d', $item->pointer)
      if $item->name =~ m{^etc/rc(?:\d|S)?\.d/\S}
      && (none { $self->processable->name eq $_ } qw(sysvinit file-rc))
      && $self->processable->type ne 'udeb';

    # /etc/rc.boot
    $self->pointed_hint('package-installs-into-etc-rc.boot', $item->pointer)
      if $item->name =~ m{^etc/rc\.boot/\S};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# control-files -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2017 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::ControlFiles;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $SPACE => q{ };
const my $SLASH => q{/};

const my $WIDELY_EXECUTABLE => oct(111);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has ships_ctrl_script => (is => 'rw', default =>  0);

sub visit_control_files {
    my ($self, $item) = @_;

    my $type = $self->processable->type;
    my $processable = $self->processable;

    my $DEB_PERMISSIONS
      = $self->data->load('control-files/deb-permissions',qr/\s+/);
    my $UDEB_PERMISSIONS
      = $self->data->load('control-files/udeb-permissions',qr/\s+/);

    my $ctrl = $type eq 'udeb' ? $UDEB_PERMISSIONS : $DEB_PERMISSIONS;
    my $ctrl_alt = $type eq 'udeb' ? $DEB_PERMISSIONS : $UDEB_PERMISSIONS;

    # the control.tar.gz should only contain files (and the "root"
    # dir, but that is excluded from the index)
    if (!$item->is_regular_file) {

        $self->pointed_hint('control-file-is-not-a-file', $item->pointer);
        # Doing further checks is probably not going to yield anything
        # remotely useful.
        return;
    }

    # valid control file?
    unless ($ctrl->recognizes($item->name)) {

        if ($ctrl_alt->recognizes($item->name)) {
            $self->pointed_hint('not-allowed-control-file', $item->pointer);

        } else {
            $self->pointed_hint('unknown-control-file', $item->pointer);
        }

        return;
    }

    my $experm = oct($ctrl->value($item->name));

    $self->pointed_hint('control-file-is-empty', $item->pointer)
      if $item->size == 0
      && $item->basename ne 'md5sums';

    # skip `control' control file (that's an exception: dpkg
    # doesn't care and this file isn't installed on the systems
    # anyways)
    return
      if $item->name eq 'control';

    my $operm = $item->operm;
    if ($item->is_executable || $experm & $WIDELY_EXECUTABLE) {

        $self->ships_ctrl_script(1);
        $self->pointed_hint('ctrl-script', $item->pointer);
    }

    # correct permissions?
    unless ($operm == $experm) {

        $self->pointed_hint('control-file-has-bad-permissions',
            $item->pointer,sprintf('%04o != %04o', $operm, $experm));
    }

    # correct owner?
    unless ($item->identity eq 'root/root' || $item->identity eq '0/0') {

        $self->pointed_hint('control-file-has-bad-owner',$item->pointer,
            $item->identity,'!= root/root (or 0/0)');
    }

    # for other maintainer scripts checks, see the scripts check

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint('no-ctrl-scripts')
      unless $self->ships_ctrl_script;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

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

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };
const my $SLASH => q{/};

const my $WIDELY_EXECUTABLE => oct(111);

sub octify {
    my (undef, $val) = @_;

    return oct($val);
}

sub installable {
    my ($self) = @_;

    my $type = $self->processable->type;
    my $processable = $self->processable;

    my $DEB_PERMISSIONS
      = $self->profile->load_data('control-files/deb-permissions',
        qr/\s++/, \&octify);
    my $UDEB_PERMISSIONS
      = $self->profile->load_data('control-files/udeb-permissions',
        qr/\s++/, \&octify);

    my $ctrl = $type eq 'udeb' ? $UDEB_PERMISSIONS : $DEB_PERMISSIONS;
    my $ctrl_alt = $type eq 'udeb' ? $DEB_PERMISSIONS : $UDEB_PERMISSIONS;
    my $has_ctrl_script = 0;

    # process control-index file
    for my $file (@{$processable->control->sorted_list}) {

        # the control.tar.gz should only contain files (and the "root"
        # dir, but that is excluded from the index)
        if (not $file->is_regular_file) {
            $self->hint('control-file-is-not-a-file', $file);
            # Doing further checks is probably not going to yield anything
            # remotely useful.
            next;
        }

        # valid control file?
        unless ($ctrl->recognizes($file)) {
            if ($ctrl_alt->recognizes($file)) {
                $self->hint('not-allowed-control-file', $file);
                next;
            } else {
                $self->hint('unknown-control-file', $file);
                next;
            }
        }

        my $experm = $ctrl->value($file);

        if ($file->size == 0 and $file->basename ne 'md5sums') {
            $self->hint('control-file-is-empty', $file);
        }

        # skip `control' control file (that's an exception: dpkg
        # doesn't care and this file isn't installed on the systems
        # anyways)
        next if $file eq 'control';

        my $operm = $file->operm;
        if ($file->is_executable || $experm & $WIDELY_EXECUTABLE) {
            $has_ctrl_script = 1;
            $self->hint('ctrl-script', $file);
        }

        # correct permissions?
        unless ($operm == $experm) {
            $self->hint('control-file-has-bad-permissions',
                sprintf('%s %04o != %04o', $file, $operm, $experm));
        }

        my $ownership = $file->owner . $SLASH . $file->group;

        # correct owner?
        unless ($file->identity eq 'root/root' || $file->identity eq '0/0') {
            $self->hint('control-file-has-bad-owner',
                    $file->name
                  . $SPACE
                  . $file->identity
                  . ' != root/root (or 0/0)');
        }

        # for other maintainer scripts checks, see the scripts check
    }
    if (not $has_ctrl_script) {
        $self->hint('no-ctrl-scripts');
    }
    return;
} # </run>

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

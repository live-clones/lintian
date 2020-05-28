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

package Lintian::control_files;

use v5.20;
use warnings;
use utf8;
use autodie;

use constant SPACE => q{ };

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub octify {
    my (undef, $val) = @_;
    return oct($val);
}

my $DEB_PERMISSIONS
  = Lintian::Data->new('control-files/deb-permissions',  qr/\s++/, \&octify);
my $UDEB_PERMISSIONS
  = Lintian::Data->new('control-files/udeb-permissions', qr/\s++/, \&octify);

sub installable {
    my ($self) = @_;

    my $type = $self->type;
    my $processable = $self->processable;

    my $ctrl = $type eq 'udeb' ? $UDEB_PERMISSIONS : $DEB_PERMISSIONS;
    my $ctrl_alt = $type eq 'udeb' ? $DEB_PERMISSIONS : $UDEB_PERMISSIONS;
    my $has_ctrl_script = 0;

    # process control-index file
    foreach my $file ($processable->control->sorted_list) {

        # the control.tar.gz should only contain files (and the "root"
        # dir, but that is excluded from the index)
        if (not $file->is_regular_file) {
            $self->tag('control-file-is-not-a-file', $file);
            # Doing further checks is probably not going to yield anything
            # remotely useful.
            next;
        }

        # valid control file?
        unless ($ctrl->known($file)) {
            if ($ctrl_alt->known($file)) {
                $self->tag('not-allowed-control-file', $file);
                next;
            } else {
                $self->tag('unknown-control-file', $file);
                next;
            }
        }

        my $experm = $ctrl->value($file);

        if ($file->size == 0 and $file->basename ne 'md5sums') {
            $self->tag('control-file-is-empty', $file);
        }

        # skip `control' control file (that's an exception: dpkg
        # doesn't care and this file isn't installed on the systems
        # anyways)
        next if $file eq 'control';

        my $operm = $file->operm;
        if ($operm & 0111 or $experm & 0111) {
            $has_ctrl_script = 1;
            $self->tag('ctrl-script', $file);
        }

        # correct permissions?
        unless ($operm == $experm) {
            $self->tag('control-file-has-bad-permissions',
                sprintf('%s %04o != %04o', $file, $operm, $experm));
        }

        my $ownership = $file->owner . '/' . $file->group;

        # correct owner?
        unless ($file->identity eq 'root/root' || $file->identity eq '0/0') {
            $self->tag('control-file-has-bad-owner',
                $file->name. SPACE. $file->identity. ' != root/root (or 0/0)');
        }

        # for other maintainer scripts checks, see the scripts check
    }
    if (not $has_ctrl_script) {
        $self->tag('no-ctrl-scripts');
    }
    return;
} # </run>

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

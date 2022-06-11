# files/permissions -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Check::Files::Permissions;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;

const my $NOT_EQUAL => q{!=};

const my $STANDARD_EXECUTABLE => oct(755);
const my $SETGID_EXECUTABLE => oct(4754);
const my $SET_USER_ID => oct(4000);
const my $SET_GROUP_ID => oct(2000);

const my $STANDARD_FILE => oct(644);
const my $BACKUP_NINJA_FILE => oct(600);
const my $SUDOERS_FILE => oct(440);
const my $GAME_DATA => oct(664);

const my $STANDARD_FOLDER => oct(755);
const my $GAME_FOLDER => oct(2775);
const my $VAR_LOCAL_FOLDER => oct(2775);
const my $VAR_LOCK_FOLDER => oct(1777);
const my $USR_SRC_FOLDER => oct(2775);

const my $WORLD_READABLE => oct(444);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has component => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return path($self->processable->path)->basename;
    }
);

has linked_against_libvga => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %linked_against_libvga;

        for my $item (@{$self->processable->installed->sorted_list}) {

            for my $library (@{$item->elf->{NEEDED} // []}){

                $linked_against_libvga{$item->name} = 1
                  if $library =~ m{^ libvga[.]so[.] }x;
            }
        }

        return \%linked_against_libvga;
    }
);

sub visit_installed_files {
    my ($self, $item) = @_;

    if ($item->is_file) {

        if (
            $item->is_executable
            && $item->identity eq 'root/games'
            && (   !$item->is_setgid
                || !$item->all_bits_set($STANDARD_EXECUTABLE))
        ) {

            $self->pointed_hint(
                'non-standard-game-executable-perm',
                $item->pointer,
                $item->octal_permissions,
                $NOT_EQUAL,
                sprintf('%04o', $SET_GROUP_ID | $STANDARD_EXECUTABLE)
            );

            return;
        }

        $self->pointed_hint('executable-is-not-world-readable',
            $item->pointer, $item->octal_permissions)
          if $item->is_executable
          && !$item->all_bits_set($WORLD_READABLE);

        if ($item->is_setuid || $item->is_setgid) {

            $self->pointed_hint('non-standard-setuid-executable-perm',
                $item->pointer, $item->octal_permissions)
              unless (($item->operm & ~($SET_USER_ID | $SET_GROUP_ID))
                == $STANDARD_EXECUTABLE)
              || $item->operm == $SETGID_EXECUTABLE;
        }

        # allow anything with suid in the name
        return
          if ($item->is_setuid || $item->is_setgid)
          && $self->processable->name =~ / -suid /msx;

        # program is using svgalib
        return
          if $item->is_setuid
          && !$item->is_setgid
          && $item->owner eq 'root'
          && exists $self->linked_against_libvga->{$item->name};

        # program is a setgid game
        return
          if $item->is_setgid
          && !$item->is_setuid
          && $item->group eq 'games'
          && $item->name =~ m{^ usr/ (?:lib/)? games/ \S+ }msx;

        if ($item->is_setuid || $item->is_setgid) {
            $self->pointed_hint(
                'elevated-privileges', $item->pointer,
                $item->octal_permissions, $item->identity
            );

            return;
        }

        if (   $item->is_executable
            && $item->operm != $STANDARD_EXECUTABLE) {

            $self->pointed_hint('non-standard-executable-perm',
                $item->pointer, $item->octal_permissions, $NOT_EQUAL,
                sprintf('%04o', $STANDARD_EXECUTABLE));

            return;
        }

        if (!$item->is_executable) {

            # game data
            return
              if $item->operm == $GAME_DATA
              && $item->identity eq 'root/games'
              && $item->name =~ m{^ var/ (?:lib/)? games/ \S+ }msx;

            # GNAT compiler wants read-only Ada library information.
            if (   $item->name =~ m{^ usr/lib/ .* [.]ali $}msx
                && $item->operm != $WORLD_READABLE) {

                $self->pointed_hint('bad-permissions-for-ali-file',
                    $item->pointer);

                return;
            }

            # backupninja expects configurations files to be oct(600)
            return
              if $item->operm == $BACKUP_NINJA_FILE
              && $item->name =~ m{^ etc/backup.d/ }msx;

            if ($item->name =~ m{^ etc/sudoers.d/ }msx) {

                # sudo requires sudoers files to be mode oct(440)
                $self->pointed_hint(
                    'bad-perm-for-file-in-etc-sudoers.d',$item->pointer,
                    $item->octal_permissions, $NOT_EQUAL,
                    sprintf('%04o', $SUDOERS_FILE)
                )unless $item->operm == $SUDOERS_FILE;

                return;
            }

            $self->pointed_hint(
                'non-standard-file-perm', $item->pointer,
                $item->octal_permissions, $NOT_EQUAL,
                sprintf('%04o', $STANDARD_FILE)
            )unless $item->operm == $STANDARD_FILE;
        }

    }

    if ($item->is_dir) {

        # game directory with setgid bit
        return
          if $item->operm == $GAME_FOLDER
          && $item->identity eq 'root/games'
          && $item->name =~ m{^ var/ (?:lib/)? games/ \S+ }msx;

        # shipping files here triggers warnings elsewhere
        return
          if $item->operm == $VAR_LOCK_FOLDER
          && $item->identity eq 'root/root'
          && ( $item->name =~ m{^ (?:var/)? tmp/ }msx
            || $item->name eq 'var/lock/');

        # shipping files here triggers warnings elsewhere
        return
          if $item->operm == $VAR_LOCAL_FOLDER
          && $item->identity eq 'root/staff'
          && $item->name eq 'var/local/';

        # /usr/src created by base-files
        return
          if $item->operm == $USR_SRC_FOLDER
          && $item->identity eq 'root/src'
          && $item->name eq 'usr/src/';

        $self->pointed_hint(
            'non-standard-dir-perm', $item->pointer,
            $item->octal_permissions, $NOT_EQUAL,
            sprintf('%04o', $STANDARD_FOLDER)
        )unless $item->operm == $STANDARD_FOLDER;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

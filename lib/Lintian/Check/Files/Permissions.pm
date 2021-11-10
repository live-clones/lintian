# files/permissions -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2020 Felix Lechner
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

use Moo;
use namespace::clean;

with 'Lintian::Check';

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

has component => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return path($self->processable->path)->basename;
    });

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
    });

sub visit_installed_files {
    my ($self, $file) = @_;

    if ($file->is_file) {

        if (
               $file->is_executable
            && $file->identity eq 'root/games'
            && (   !$file->is_setgid
                || !$file->all_bits_set($STANDARD_EXECUTABLE))
        ) {

            $self->hint(
                'non-standard-game-executable-perm',
                $file->name,
                $file->octal_permissions,
                $NOT_EQUAL,
                sprintf('%04o', $SET_GROUP_ID | $STANDARD_EXECUTABLE));

            return;
        }

        $self->hint('executable-is-not-world-readable',
            $file->name, $file->octal_permissions)
          if $file->is_executable
          && !$file->all_bits_set($WORLD_READABLE);

        if ($file->is_setuid || $file->is_setgid) {

            $self->hint('non-standard-setuid-executable-perm',
                $file->name, $file->octal_permissions)
              unless (($file->operm & ~($SET_USER_ID | $SET_GROUP_ID))
                == $STANDARD_EXECUTABLE)
              || $file->operm == $SETGID_EXECUTABLE;
        }

        # allow anything with suid in the name
        return
          if ($file->is_setuid || $file->is_setgid)
          && $self->processable->name =~ / -suid /msx;

        # program is using svgalib
        return
             if $file->is_setuid
          && !$file->is_setgid
          && $file->owner eq 'root'
          && exists $self->linked_against_libvga->{$file->name};

        # program is a setgid game
        return
             if $file->is_setgid
          && !$file->is_setuid
          && $file->group eq 'games'
          && $file->name =~ m{^ usr/ (?:lib/)? games/ \S+ }msx;

        if ($file->is_setuid || $file->is_setgid) {
            $self->hint(
                'elevated-privileges', $file->name,
                $file->octal_permissions, $file->identity
            );

            return;
        }

        if (   $file->is_executable
            && $file->operm != $STANDARD_EXECUTABLE) {

            $self->hint('non-standard-executable-perm',
                $file->name, $file->octal_permissions, $NOT_EQUAL,
                sprintf('%04o', $STANDARD_EXECUTABLE));

            return;
        }

        if (!$file->is_executable) {

            # game data
            return
                 if $file->operm == $GAME_DATA
              && $file->identity eq 'root/games'
              && $file->name =~ m{^ var/ (?:lib/)? games/ \S+ }msx;

            # GNAT compiler wants read-only Ada library information.
            if (   $file->name =~ m{^ usr/lib/ .* [.]ali $}msx
                && $file->operm != $WORLD_READABLE) {

                $self->hint('bad-permissions-for-ali-file', $file->name);

                return;
            }

            # backupninja expects configurations files to be oct(600)
            return
              if $file->operm == $BACKUP_NINJA_FILE
              && $file->name =~ m{^ etc/backup.d/ }msx;

            if ($file->name =~ m{^ etc/sudoers.d/ }msx) {

                # sudo requires sudoers files to be mode oct(440)
                $self->hint(
                    'bad-perm-for-file-in-etc-sudoers.d',$file->name,
                    $file->octal_permissions, $NOT_EQUAL,
                    sprintf('%04o', $SUDOERS_FILE)
                )unless $file->operm == $SUDOERS_FILE;

                return;
            }

            $self->hint(
                'non-standard-file-perm', $file->name,
                $file->octal_permissions, $NOT_EQUAL,
                sprintf('%04o', $STANDARD_FILE)
            )unless $file->operm == $STANDARD_FILE;
        }

    }

    if ($file->is_dir) {

        # game directory with setgid bit
        return
             if $file->operm == $GAME_FOLDER
          && $file->identity eq 'root/games'
          && $file->name =~ m{^ var/ (?:lib/)? games/ \S+ }msx;

        # shipping files here triggers warnings elsewhere
        return
             if $file->operm == $VAR_LOCK_FOLDER
          && $file->identity eq 'root/root'
          && ( $file->name =~ m{^ (?:var/)? tmp/ }msx
            || $file->name eq 'var/lock/');

        # shipping files here triggers warnings elsewhere
        return
             if $file->operm == $VAR_LOCAL_FOLDER
          && $file->identity eq 'root/staff'
          && $file->name eq 'var/local/';

        # /usr/src created by base-files
        return
             if $file->operm == $USR_SRC_FOLDER
          && $file->identity eq 'root/src'
          && $file->name eq 'usr/src/';

        $self->hint(
            'non-standard-dir-perm', $file->name,
            $file->octal_permissions, $NOT_EQUAL,
            sprintf('%04o', $STANDARD_FOLDER)
        )unless $file->operm == $STANDARD_FOLDER;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

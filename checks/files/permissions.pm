# files/permissions -- lintian check script -*- perl -*-

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

package Lintian::files::permissions;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has linked_against_libvga => (is => 'rwp');

sub setup {
    my ($self) = @_;

    my %linked_against_libvga;

    # read data from objdump-info file
    my $table = $self->processable->objdump_info;

    foreach my $file (sort keys %{$table}) {
        my $objdump = $table->{$file};

        next
          unless defined $objdump->{NEEDED};

        for my $lib (@{$objdump->{NEEDED}}) {
            $linked_against_libvga{$file} = 1
              if $lib =~ /^libvga\.so\./;
        }
    }

    $self->_set_linked_against_libvga(\%linked_against_libvga);
    return;
}

sub files {
    my ($self, $file) = @_;

    if ($file->is_file) {

        if ($file->operm & 06000) {

            # general: setuid/setgid files
            my ($setuid, $setgid) = ('','');

            $setuid = $file->owner if $file->operm & 04000;
            $setgid = $file->group if $file->operm & 02000;

            # 1st special case: program is using svgalib:
            if (exists $self->linked_against_libvga->{$file->name}) {
                # setuid root is ok, so remove it

                undef $setuid
                  if $setuid eq 'root';
            }

            # 2nd special case: program is a setgid game
            if (   $file->name =~ m,^usr/lib/games/\S+,
                or $file->name =~ m,^usr/games/\S+,) {

                # setgid games is ok, so remove it
                undef $setgid
                  if $setgid eq 'games';
            }

            # 3rd special case: allow anything with suid in the name
            undef $setuid
              if $self->package =~ m,-suid,;

            # Check for setuid and setgid that isn't expected.
            if ($setuid and $setgid) {
                $self->tag('setuid-gid-binary', $file->name,
                    sprintf('%04o %s',$file->operm,$file->identity));
            } elsif ($setuid) {
                $self->tag('setuid-binary', $file->name,
                    sprintf('%04o %s',$file->operm,$file->identity));
            } elsif ($setgid) {
                $self->tag('setgid-binary', $file->name,
                    sprintf('%04o %s',$file->operm,$file->identity));
            }

            # Check for permission problems other than the setuid status.
            if (($file->operm & 0444) != 0444) {
                $self->tag('executable-is-not-world-readable',
                    $file->name,sprintf('%04o',$file->operm));
            } elsif ($file->operm != 04755
                && $file->operm != 02755
                && $file->operm != 06755
                && $file->operm != 04754) {

                $self->tag('non-standard-setuid-executable-perm',
                    $file->name,sprintf('%04o',$file->operm));
            }
        }elsif ($file->operm & 0111) {

            # general: executable files
            if ($file->identity eq 'root/games') {
                if ($file->operm != 2755) {
                    $self->tag('non-standard-game-executable-perm',
                        $file->name,sprintf('%04o != 2755',$file->operm));
                }
            } else {
                if (($file->operm & 0444) != 0444) {
                    $self->tag('executable-is-not-world-readable',
                        $file->name,sprintf('%04o',$file->operm));

                } elsif ($file->operm != 0755) {
                    $self->tag('non-standard-executable-perm',
                        $file->name,sprintf('%04o != 0755',$file->operm));
                }
            }
        }else {
            # general: normal (non-executable) files

            # special case first: game data
            if (    $file->operm == 0664
                and $file->identity eq 'root/games'
                and $file->name =~ m,^var/(lib/)?games/\S+,) {
                # everything is ok

            } elsif ($file->name =~ m,^usr/lib/.*\.ali$,) {
                # GNAT compiler wants read-only Ada library information.
                $self->tag('bad-permissions-for-ali-file', $file->name)
                  unless $file->operm == 0444;

            } elsif ($file->operm == 0600 and $file->name =~ m,^etc/backup.d/,)
            {
                # backupninja expects configurations files to be 0600

            } elsif ($file->name =~ m,^etc/sudoers.d/,) {
                # sudo requires sudoers files to be mode 0440
                $self->tag('bad-perm-for-file-in-etc-sudoers.d',
                    $file->name,sprintf('%04o != 0440', $file->operm))
                  unless $file->operm == 0440;

            } elsif ($file->operm != 0644) {
                $self->tag('non-standard-file-perm', $file->name,
                    sprintf('%04o != 0644',$file->operm));
            }
        }

    }elsif ($file->is_dir) {

        # special cases first:
        # game directory with setgid bit
        if (    $file->name =~ m,^var/(?:lib/)?games/\S+,
            and $file->operm == 02775
            and $file->identity eq 'root/games') {
            # do nothing, this is allowed, but not mandatory

        } elsif ((
                   $file->name eq 'tmp/'
                or $file->name eq 'var/tmp/'
                or $file->name eq 'var/lock/'
            )
            and $file->operm == 01777
            and $file->identity eq 'root/root'
        ) {
            # actually shipping files here is warned about elsewhere

        } elsif ($file->name eq 'usr/src/'
            and $file->operm == 02775
            and $file->identity eq 'root/src') {
            # /usr/src as created by base-files is a special exception

        } elsif ($file->name eq 'var/local/'
            and $file->operm == 02775
            and $file->identity eq 'root/staff') {
            # actually shipping files here is warned about elsewhere

        }elsif ($file->operm != 0755) {
            # otherwise, complain if it's not 0755.
            $self->tag('non-standard-dir-perm', $file->name,
                sprintf('%04o != 0755', $file->operm));
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

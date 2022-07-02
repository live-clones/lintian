# files/hierarchy/standard -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::Hierarchy::Standard;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub _is_tmp_path {
    my ($path) = @_;

    return 1
      if $path =~ m{^tmp/.}
      || $path =~ m{^(?:var|usr)/tmp/.}
      || $path =~ m{^/dev/shm/};

    return 0;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    if ($item->name =~ m{^etc/opt/.}) {

        # /etc/opt
        $self->pointed_hint('dir-or-file-in-etc-opt', $item->pointer);

    } elsif ($item->name =~ m{^usr/local/\S+}) {
        # /usr/local
        if ($item->is_dir) {
            $self->pointed_hint('dir-in-usr-local', $item->pointer);
        } else {
            $self->pointed_hint('file-in-usr-local', $item->pointer);
        }

    } elsif ($item->name =~ m{^usr/share/[^/]+$}) {
        # /usr/share
        $self->pointed_hint('file-directly-in-usr-share', $item->pointer)
          if $item->is_file;

    } elsif ($item->name =~ m{^usr/bin/}) {
        # /usr/bin
        $self->pointed_hint('subdir-in-usr-bin', $item->pointer)
          if $item->is_dir
          && $item->name =~ m{^usr/bin/.}
          && $item->name !~ m{^usr/bin/(?:X11|mh)/};

    } elsif ($self->processable->type ne 'udeb'
        && $item->name =~ m{^usr/[^/]+/$}) {

        # /usr subdirs
        if ($item->name=~ m{^usr/(?:dict|doc|etc|info|man|adm|preserve)/}) {
            # FSSTND dirs
            $self->pointed_hint('FSSTND-dir-in-usr', $item->pointer);
        } elsif (
            $item->name !~ m{^usr/(?:X11R6|X386|
                                    bin|games|include|
                                    lib|
                                    local|sbin|share|
                                    src|spool|tmp)/}x
        ) {
            # FHS dirs
            if ($item->name =~ m{^usr/lib(?<libsuffix>64|x?32)/}) {
                my $libsuffix = $+{libsuffix};
                # eglibc exception is due to FHS. Other are
                # transitional, waiting for full
                # implementation of multi-arch.  Note that we
                # allow (e.g.) "lib64" packages to still use
                # these dirs, since their use appears to be by
                # intention.
                unless ($self->processable->source_name =~ m/^e?glibc$/
                    or $self->processable->name =~ m/^lib$libsuffix/) {

                    $self->pointed_hint('non-multi-arch-lib-dir',
                        $item->pointer);
                }
            } else {
                # see Bug#834607
                $self->pointed_hint('non-standard-dir-in-usr', $item->pointer)
                  unless $item->name =~ m{^usr/libexec/};
            }

        }

        # unless $item =~ m,^usr/[^/]+-linuxlibc1/,; was tied
        # into print above...
        # Make an exception for the altdev dirs, which will go
        # away at some point and are not worth moving.
    }

    # /var subdirs
    elsif ($self->processable->type ne 'udeb'
        && $item->name =~ m{^var/[^/]+/$}) {

        if ($item->name =~ m{^var/(?:adm|catman|named|nis|preserve)/}) {
            # FSSTND dirs
            $self->pointed_hint('FSSTND-dir-in-var', $item->pointer);

        } elsif ($self->processable->name eq 'base-files'
            && $item->name =~ m{^var/(?:backups|local)/}) {
            # base-files is special
            # ignore

        } elsif (
            $item->name !~ m{\A var/
                             (?: account|lib|cache|crash|games
                                |lock|log|opt|run|spool|state
                                |tmp|www|yp)/
             }xsm
        ) {
            # FHS dirs with exception in Debian policy
            $self->pointed_hint('non-standard-dir-in-var', $item->pointer);
        }

    } elsif ($self->processable->type ne 'udeb'
        && $item->name =~ m{^var/lib/games/.}) {
        $self->pointed_hint('non-standard-dir-in-var', $item->pointer);

    } elsif ($self->processable->type ne 'udeb'
        && $item->name =~ m{^var/lock/.}) {
        # /var/lock
        $self->pointed_hint('dir-or-file-in-var-lock', $item->pointer);

    } elsif ($self->processable->type ne 'udeb'
        && $item->name =~ m{^var/run/.}) {
        # /var/run
        $self->pointed_hint('dir-or-file-in-var-run', $item->pointer);

    } elsif ($self->processable->type ne 'udeb' && $item->name =~ m{^run/.}) {
        $self->pointed_hint('dir-or-file-in-run', $item->pointer);

    } elsif ($item->name =~ m{^var/www/\S+}) {
        # /var/www
        # Packages are allowed to create /var/www since it's
        # historically been the default document root, but they
        # shouldn't be installing stuff under that directory.
        $self->pointed_hint('dir-or-file-in-var-www', $item->pointer);

    } elsif ($item->name =~ m{^opt/.}) {
        # /opt
        $self->pointed_hint('dir-or-file-in-opt', $item->pointer);

    } elsif ($item->name =~ m{^hurd/}) {
        return;

    } elsif ($item->name =~ m{^servers/}) {
        return;

    } elsif ($item->name =~ m{^home/.}) {
        # /home
        $self->pointed_hint('dir-or-file-in-home', $item->pointer);

    } elsif ($item->name =~ m{^root/.}) {
        $self->pointed_hint('dir-or-file-in-home', $item->pointer);

    } elsif (_is_tmp_path($item->name)) {
        # /tmp, /var/tmp, /usr/tmp
        $self->pointed_hint('dir-or-file-in-tmp', $item->pointer);

    } elsif ($item->name =~ m{^mnt/.}) {
        # /mnt
        $self->pointed_hint('dir-or-file-in-mnt', $item->pointer);

    } elsif ($item->name =~ m{^bin/}) {
        # /bin
        $self->pointed_hint('subdir-in-bin', $item->pointer)
          if $item->is_dir && $item->name =~ m{^bin/.};

    } elsif ($item->name =~ m{^srv/.}) {
        # /srv
        $self->pointed_hint('dir-or-file-in-srv', $item->pointer);

    }elsif (
        $item->name =~ m{^[^/]+/$}
        && $item->name !~ m{\A (?:
                  bin|boot|dev|etc|home|lib
                 |mnt|opt|root|run|sbin|srv|sys
                 |tmp|usr|var)  /
          }xsm
    ) {
        # FHS directory?

        # Make an exception for the base-files package here and
        # other similar packages because they install a slew of
        # top-level directories for setting up the base system.
        # (Specifically, /cdrom, /floppy, /initrd, and /proc are
        # not mentioned in the FHS).
        if ($item->name =~ m{^lib(?<libsuffix>64|x?32)/}) {
            my $libsuffix = $+{libsuffix};

            # see comments for ^usr/lib(?'libsuffix'64|x?32)
            $self->pointed_hint('non-multi-arch-lib-dir', $item->pointer)
              unless $self->processable->source_name =~ m/^e?glibc$/
              || $self->processable->name =~ m/^lib$libsuffix/;

        } else {
            $self->pointed_hint('non-standard-toplevel-dir', $item->pointer)
              unless $self->processable->name eq 'base-files'
              || $self->processable->name eq 'hurd'
              || $self->processable->name eq 'hurd-udeb'
              || $self->processable->name =~ /^rootskel(?:-bootfloppy)?/;
        }
    }

    # compatibility symlinks should not be used
    $self->pointed_hint('use-of-compat-symlink', $item->pointer)
      if $item->name =~ m{^usr/(?:spool|tmp)/}
      || $item->name =~ m{^usr/(?:doc|bin)/X11/}
      || $item->name =~ m{^var/adm/};

    # any files
    $self->pointed_hint('file-in-unusual-dir', $item->pointer)
      unless $item->is_dir
      || $self->processable->type eq 'udeb'
      || $item->name =~ m{^usr/(?:bin|dict|doc|games|
                                    include|info|lib(?:x?32|64)?|
                                    man|sbin|share|src|X11R6)/}x
      || $item->name =~ m{^lib(?:x?32|64)?/(?:modules/|libc5-compat/)?}
      || $item->name =~ m{^var/(?:games|lib|www|named)/}
      || $item->name =~ m{^(?:bin|boot|dev|etc|sbin)/}
      # non-FHS, but still usual
      || $item->name =~ m{^usr/[^/]+-linux[^/]*/}
      || $item->name =~ m{^usr/libexec/} # FHS 3.0 / #834607
      || $item->name =~ m{^usr/iraf/}
      # not allowed, but tested individually
      || $item->name =~ m{\A (?:
                        build|home|mnt|opt|root|run|srv
                       |(?:(?:usr|var)/)?tmp)|var/www/}xsm;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

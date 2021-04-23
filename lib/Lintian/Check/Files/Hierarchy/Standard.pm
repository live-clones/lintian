# files/hierarchy/standard -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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
    my ($self, $file) = @_;

    if ($file->name =~ m{^etc/opt/.}) {

        # /etc/opt
        $self->hint('dir-or-file-in-etc-opt', $file->name);

    } elsif ($file->name =~ m{^usr/local/\S+}) {
        # /usr/local
        if ($file->is_dir) {
            $self->hint('dir-in-usr-local', $file->name);
        } else {
            $self->hint('file-in-usr-local', $file->name);
        }

    } elsif ($file->name =~ m{^usr/share/[^/]+$}) {
        # /usr/share
        $self->hint('file-directly-in-usr-share', $file->name)
          if $file->is_file;

    } elsif ($file->name =~ m{^usr/bin/}) {
        # /usr/bin
        $self->hint('subdir-in-usr-bin', $file->name)
          if $file->is_dir
          && $file->name =~ m{^usr/bin/.}
          && $file->name !~ m{^usr/bin/(?:X11|mh)/};

    } elsif ($self->processable->type ne 'udeb'
        && $file->name =~ m{^usr/[^/]+/$}) {

        # /usr subdirs
        if ($file->name=~ m{^usr/(?:dict|doc|etc|info|man|adm|preserve)/}) {
            # FSSTND dirs
            $self->hint('FSSTND-dir-in-usr', $file->name);
        } elsif (
            $file->name !~ m{^usr/(?:X11R6|X386|
                                    bin|games|include|
                                    lib|
                                    local|sbin|share|
                                    src|spool|tmp)/}x
        ) {
            # FHS dirs
            if ($file->name =~ m{^usr/lib(?<libsuffix>64|x?32)/}) {
                my $libsuffix = $+{libsuffix};
                # eglibc exception is due to FHS. Other are
                # transitional, waiting for full
                # implementation of multi-arch.  Note that we
                # allow (e.g.) "lib64" packages to still use
                # these dirs, since their use appears to be by
                # intention.
                unless ($self->processable->source_name =~ m/^e?glibc$/
                    or $self->processable->name =~ m/^lib$libsuffix/) {

                    $self->hint('non-multi-arch-lib-dir', $file->name);
                }
            } else {
                # see Bug#834607
                $self->hint('non-standard-dir-in-usr', $file->name)
                  unless $file->name =~ m{^usr/libexec/};
            }

        }

        # unless $file =~ m,^usr/[^/]+-linuxlibc1/,; was tied
        # into print above...
        # Make an exception for the altdev dirs, which will go
        # away at some point and are not worth moving.
    }

    # /var subdirs
    elsif ($self->processable->type ne 'udeb'
        && $file->name =~ m{^var/[^/]+/$}) {

        if ($file->name =~ m{^var/(?:adm|catman|named|nis|preserve)/}) {
            # FSSTND dirs
            $self->hint('FSSTND-dir-in-var', $file->name);

        } elsif ($self->processable->name eq 'base-files'
            && $file->name =~ m{^var/(?:backups|local)/}) {
            # base-files is special
            # ignore

        } elsif (
            $file->name !~ m{\A var/
                             (?: account|lib|cache|crash|games
                                |lock|log|opt|run|spool|state
                                |tmp|www|yp)/
             }xsm
        ) {
            # FHS dirs with exception in Debian policy
            $self->hint('non-standard-dir-in-var', $file->name);
        }

    } elsif ($self->processable->type ne 'udeb'
        && $file->name =~ m{^var/lib/games/.}) {
        $self->hint('non-standard-dir-in-var', $file->name);

    } elsif ($self->processable->type ne 'udeb'
        && $file->name =~ m{^var/lock/.}) {
        # /var/lock
        $self->hint('dir-or-file-in-var-lock', $file->name);

    } elsif ($self->processable->type ne 'udeb'
        && $file->name =~ m{^var/run/.}) {
        # /var/run
        $self->hint('dir-or-file-in-var-run', $file->name);

    } elsif ($self->processable->type ne 'udeb' && $file->name =~ m{^run/.}) {
        $self->hint('dir-or-file-in-run', $file->name);

    } elsif ($file->name =~ m{^var/www/\S+}) {
        # /var/www
        # Packages are allowed to create /var/www since it's
        # historically been the default document root, but they
        # shouldn't be installing stuff under that directory.
        $self->hint('dir-or-file-in-var-www', $file->name);

    } elsif ($file->name =~ m{^opt/.}) {
        # /opt
        $self->hint('dir-or-file-in-opt', $file->name);

    } elsif ($file->name =~ m{^hurd/}) {
        return;

    } elsif ($file->name =~ m{^servers/}) {
        return;

    } elsif ($file->name =~ m{^home/.}) {
        # /home
        $self->hint('dir-or-file-in-home', $file->name);

    } elsif ($file->name =~ m{^root/.}) {
        $self->hint('dir-or-file-in-home', $file->name);

    } elsif (_is_tmp_path($file->name)) {
        # /tmp, /var/tmp, /usr/tmp
        $self->hint('dir-or-file-in-tmp', $file->name);

    } elsif ($file->name =~ m{^mnt/.}) {
        # /mnt
        $self->hint('dir-or-file-in-mnt', $file->name);

    } elsif ($file->name =~ m{^bin/}) {
        # /bin
        $self->hint('subdir-in-bin', $file->name)
          if $file->is_dir && $file->name =~ m{^bin/.};

    } elsif ($file->name =~ m{^srv/.}) {
        # /srv
        $self->hint('dir-or-file-in-srv', $file->name);

    }elsif (
        $file->name =~ m{^[^/]+/$}
        && $file->name !~ m{\A (?:
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
        if ($file->name =~ m{^lib(?<libsuffix>64|x?32)/}) {
            my $libsuffix = $+{libsuffix};

            # see comments for ^usr/lib(?'libsuffix'64|x?32)
            $self->hint('non-multi-arch-lib-dir', $file->name)
              unless $self->processable->source_name =~ m/^e?glibc$/
              || $self->processable->name =~ m/^lib$libsuffix/;

        } else {
            $self->hint('non-standard-toplevel-dir', $file->name)
              unless $self->processable->name eq 'base-files'
              || $self->processable->name eq 'hurd'
              || $self->processable->name eq 'hurd-udeb'
              || $self->processable->name =~ /^rootskel(?:-bootfloppy)?/;
        }
    }

    # compatibility symlinks should not be used
    $self->hint('use-of-compat-symlink', $file->name)
      if $file->name =~ m{^usr/(?:spool|tmp)/}
      || $file->name =~ m{^usr/(?:doc|bin)/X11/}
      || $file->name =~ m{^var/adm/};

    # any files
    $self->hint('file-in-unusual-dir', $file->name)
      unless $file->is_dir
      || $self->processable->type eq 'udeb'
      || $file->name =~ m{^usr/(?:bin|dict|doc|games|
                                    include|info|lib(?:x?32|64)?|
                                    man|sbin|share|src|X11R6)/}x
      || $file->name =~ m{^lib(?:x?32|64)?/(?:modules/|libc5-compat/)?}
      || $file->name =~ m{^var/(?:games|lib|www|named)/}
      || $file->name =~ m{^(?:bin|boot|dev|etc|sbin)/}
      # non-FHS, but still usual
      || $file->name =~ m{^usr/[^/]+-linux[^/]*/}
      || $file->name =~ m{^usr/libexec/} # FHS 3.0 / #834607
      || $file->name =~ m{^usr/iraf/}
      # not allowed, but tested individually
      || $file->name =~ m{\A (?:
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

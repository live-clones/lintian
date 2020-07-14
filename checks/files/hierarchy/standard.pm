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

package Lintian::files::hierarchy::standard;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub _is_tmp_path {
    my ($path) = @_;
    if(    $path =~ m,^tmp/.,
        or $path =~ m,^(?:var|usr)/tmp/.,
        or $path =~ m,^/dev/shm/,) {
        return 1;
    }
    return 0;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    # /etc/opt
    if ($file->name =~ m,^etc/opt/.,) {
        $self->tag('dir-or-file-in-etc-opt', $file->name);
    }

    # /usr/local
    elsif ($file->name =~ m,^usr/local/\S+,) {
        if ($file->is_dir) {
            $self->tag('dir-in-usr-local', $file->name);
        } else {
            $self->tag('file-in-usr-local', $file->name);
        }
    }
    # /usr/share
    elsif ($file->name =~ m,^usr/share/[^/]+$,) {
        if ($file->is_file) {
            $self->tag('file-directly-in-usr-share', $file->name);
        }
    }
    # /usr/bin
    elsif ($file->name =~ m,^usr/bin/,) {
        if (    $file->is_dir
            and $file->name =~ m,^usr/bin/.,
            and $file->name !~ m,^usr/bin/(?:X11|mh)/,) {

            $self->tag('subdir-in-usr-bin', $file->name);
        }
    }
    # /usr subdirs
    elsif ( $self->processable->type ne 'udeb'
        and $file->name =~ m,^usr/[^/]+/$,){
        # FSSTND dirs
        if ($file->name=~ m,^usr/(?:dict|doc|etc|info|man|adm|preserve)/,){
            $self->tag('FSSTND-dir-in-usr', $file->name);
        }
        # FHS dirs
        elsif (
            $file->name !~ m,^usr/(?:X11R6|X386|
                                    bin|games|include|
                                    lib|
                                    local|sbin|share|
                                    src|spool|tmp)/,x
        ) {
            if ($file->name =~ m,^usr/lib(?'libsuffix'64|x?32)/,) {
                my $libsuffix = $+{libsuffix};
                # eglibc exception is due to FHS. Other are
                # transitional, waiting for full
                # implementation of multi-arch.  Note that we
                # allow (e.g.) "lib64" packages to still use
                # these dirs, since their use appears to be by
                # intention.
                unless ($self->processable->source =~ m/^e?glibc$/
                    or $self->processable->name =~ m/^lib$libsuffix/) {

                    $self->tag('non-multi-arch-lib-dir', $file->name);
                }
            } else {
                $self->tag('non-standard-dir-in-usr', $file->name)
                  unless $file->name =~ m,^usr/libexec/,; # #834607
            }

        }

        # unless $file =~ m,^usr/[^/]+-linuxlibc1/,; was tied
        # into print above...
        # Make an exception for the altdev dirs, which will go
        # away at some point and are not worth moving.
    }

    # /var subdirs
    elsif ( $self->processable->type ne 'udeb'
        and $file->name =~ m,^var/[^/]+/$,){ # FSSTND dirs
        if ($file->name =~ m,^var/(?:adm|catman|named|nis|preserve)/,) {
            $self->tag('FSSTND-dir-in-var', $file->name);
        }
        # base-files is special
        elsif ($self->processable->name eq 'base-files'
            && $file->name =~ m,^var/(?:backups|local)/,){
            # ignore
        }
        # FHS dirs with exception in Debian policy
        elsif (
            $file->name !~ m{\A var/
                             (?: account|lib|cache|crash|games
                                |lock|log|opt|run|spool|state
                                |tmp|www|yp)/
             }xsm
        ) {
            $self->tag('non-standard-dir-in-var', $file->name);
        }

    } elsif ($self->processable->type ne 'udeb'
        and $file->name =~ m,^var/lib/games/.,) {
        $self->tag('non-standard-dir-in-var', $file->name);

        # /var/lock
    } elsif ($self->processable->type ne 'udeb'
        and $file->name =~ m,^var/lock/.,) {
        $self->tag('dir-or-file-in-var-lock', $file->name);

        # /var/run
    } elsif ($self->processable->type ne 'udeb'
        and $file->name =~ m,^var/run/.,) {
        $self->tag('dir-or-file-in-var-run', $file->name);
    } elsif ($self->processable->type ne 'udeb' and $file->name =~ m,^run/.,) {
        $self->tag('dir-or-file-in-run', $file->name);
    }

    # /var/www
    # Packages are allowed to create /var/www since it's
    # historically been the default document root, but they
    # shouldn't be installing stuff under that directory.
    elsif ($file->name =~ m,^var/www/\S+,) {
        $self->tag('dir-or-file-in-var-www', $file->name);
    }
    # /opt
    elsif ($file->name =~ m,^opt/.,) {
        $self->tag('dir-or-file-in-opt', $file->name);
    } elsif ($file->name =~ m,^hurd/,) {
        return;
    } elsif ($file->name =~ m,^servers/,) {
        return;
    }
    # /home
    elsif ($file->name =~ m,^home/.,) {
        $self->tag('dir-or-file-in-home', $file->name);
    } elsif ($file->name =~ m,^root/.,) {
        $self->tag('dir-or-file-in-home', $file->name);
    }
    # /tmp, /var/tmp, /usr/tmp
    elsif (_is_tmp_path($file->name)) {
        $self->tag('dir-or-file-in-tmp', $file->name);
    }
    # /mnt
    elsif ($file->name =~ m,^mnt/.,) {
        $self->tag('dir-or-file-in-mnt', $file->name);
    }
    # /bin
    elsif ($file->name =~ m,^bin/,) {
        if ($file->is_dir and $file->name =~ m,^bin/.,) {
            $self->tag('subdir-in-bin', $file->name);
        }
    }
    # /srv
    elsif ($file->name =~ m,^srv/.,) {
        $self->tag('dir-or-file-in-srv', $file->name);
    }
    # FHS directory?
    elsif (
            $file->name =~ m,^[^/]+/$,
        and $file->name !~ m{\A (?:
                  bin|boot|dev|etc|home|lib
                 |mnt|opt|root|run|sbin|srv|sys
                 |tmp|usr|var)  /
          }oxsm
    ) {
        # Make an exception for the base-files package here and
        # other similar packages because they install a slew of
        # top-level directories for setting up the base system.
        # (Specifically, /cdrom, /floppy, /initrd, and /proc are
        # not mentioned in the FHS).
        if ($file->name =~ m,^lib(?'libsuffix'64|x?32)/,) {
            my $libsuffix = $+{libsuffix};
            # see comments for ^usr/lib(?'libsuffix'64|x?32)
            unless ($self->processable->source =~ m/^e?glibc$/
                or $self->processable->name =~ m/^lib$libsuffix/) {

                $self->tag('non-multi-arch-lib-dir', $file->name);
            }
        } else {
            unless ($self->processable->name eq 'base-files'
                or $self->processable->name eq 'hurd'
                or $self->processable->name eq 'hurd-udeb'
                or $self->processable->name =~ /^rootskel(?:-bootfloppy)?/) {

                $self->tag('non-standard-toplevel-dir', $file->name);
            }
        }
    }

    # compatibility symlinks should not be used
    if (   $file->name =~ m,^usr/(?:spool|tmp)/,
        or $file->name =~ m,^usr/(?:doc|bin)/X11/,
        or $file->name =~ m,^var/adm/,) {

        $self->tag('use-of-compat-symlink', $file->name);
    }

    # any files
    if (not $file->is_dir) {
        unless (
               $self->processable->type eq 'udeb'
            or $file->name =~ m,^usr/(?:bin|dict|doc|games|
                                    include|info|lib(?:x?32|64)?|
                                    man|sbin|share|src|X11R6)/,x
            or $file->name =~ m,^lib(?:x?32|64)?/(?:modules/|libc5-compat/)?,
            or $file->name =~ m,^var/(?:games|lib|www|named)/,
            or $file->name =~ m,^(?:bin|boot|dev|etc|sbin)/,
            # non-FHS, but still usual
            or $file->name =~ m,^usr/[^/]+-linux[^/]*/,
            or $file->name =~ m,^usr/libexec/, # FHS 3.0 / #834607
            or $file->name =~ m,^usr/iraf/,
            # not allowed, but tested individually
            or $file->name =~ m{\A (?:
                        build|home|mnt|opt|root|run|srv
                       |(?:(?:usr|var)/)?tmp)|var/www/}xsm
        ) {
            $self->tag('file-in-unusual-dir', $file->name);
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

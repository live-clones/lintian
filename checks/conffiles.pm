# conffiles -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2000 Sean 'Shaleh' Perry
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

package Lintian::conffiles;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub binary {
    my ($self) = @_;

    my @files= grep { $_->is_file } $self->processable->installed->sorted_list;

    # files /etc must be conffiles, with some exceptions).
    my @etcfiles = grep { $_->name =~ m,^etc, } @files;
    for my $file (@etcfiles) {

        $self->hint('file-in-etc-not-marked-as-conffile', $file)
          unless $self->processable->is_conffile($file->name)
          || $file =~ m,/README$,
          || $file eq 'etc/init.d/skeleton'
          || $file eq 'etc/init.d/rc'
          || $file eq 'etc/init.d/rcS';
    }

    my %count;
    for my $absolute ($self->processable->conffiles) {

        # all paths should be absolute
        $self->hint('relative-conffile', $absolute)
          unless $absolute =~ m,^/,;

        # strip the leading slash
        my $relative = $absolute;
        $relative =~ s,^/++,,;

        $count{$relative} //= 0;
        $count{$relative}++;

        my $shipped = $self->processable->installed->lookup($relative);
        if (defined $shipped) {
            $self->hint('conffile-has-bad-file-type', $shipped)
              unless $shipped->is_file;

        } else {
            $self->hint('conffile-is-not-in-package', $relative);
        }

        $self->hint('file-in-etc-rc.d-marked-as-conffile', $relative)
          if $relative =~ m,^etc/rc.\.d/,;

        if ($relative !~ m,^etc/,) {
            if ($relative =~ m,^usr/,) {
                $self->hint('file-in-usr-marked-as-conffile', $relative);

            } else {
                $self->hint('non-etc-file-marked-as-conffile', $relative);
            }
        }
    }

    for my $path (keys %count) {
        $self->hint('duplicate-conffile', $path)
          if $count{$path} > 1;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

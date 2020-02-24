# maintainer-scripts/generated -- lintian check script -*- perl -*-
#
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

package Lintian::maintainer_scripts::generated;

use strict;
use warnings;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub binary {
    my ($self) = @_;

    my %tools_seen;

    # get maintainer scripts
    my %interpreters = %{$self->processable->control_scripts};

    for my $name (keys %interpreters) {

        my $interpreter = $interpreters{$name};

        # do not check for empty interpreter
        next
          unless length $interpreter;

        # do not check ELF
        next
          if $interpreter eq 'ELF';

        my $file = $self->processable->control->resolve_path($name);
        next
          unless $file;

        next
          unless $file->is_open_ok;

        # scan contents
        open(my $fd, '<', $file->unpacked_path);
        while (<$fd>) {

            # skip empty lines
            next
              if /^\s*$/;

            if (/^# Automatically added by (\S+)\s*$/) {
                my $tool = $1;
# remove trailing ":" from dh_python
# https://sources.debian.org/src/dh-python/4.20191017/dhpython/debhelper.py/#L200
                $tool =~ s/:\s*$//g;
                $tools_seen{$tool} = 1;
            }
        }

        close($fd);
    }

    $self->tag('debhelper-autoscript-in-maintainer-scripts', $_)
      for sort keys %tools_seen;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

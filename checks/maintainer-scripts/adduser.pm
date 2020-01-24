# maintainer_scripts::adduser -- lintian check script -*- perl -*-

# Copyright (C) 2020 Topi Miettinen
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

package Lintian::maintainer_scripts::adduser;

use strict;
use warnings;
use autodie;

use Lintian::Data;
use Lintian::Util qw(lstrip rstrip);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub binary {
    my ($self) = @_;

    my %scripts_found;

    # get maintainer scripts
    my %scripts = %{$self->processable->control_scripts};

    for my $name (keys %scripts) {

        my $file = $self->processable->control_index_resolved_path($name);

        next
          unless $file;

        next
          unless $file->is_open_ok;

        my $fd = $file->open;
        my $continuation = undef;

        while (<$fd>) {
            chomp;

            # merge lines ending with '\'
            if (defined($continuation)) {
                $_ = $continuation . $_;
                $continuation = undef;
            }
            if (/\\$/) {
                $continuation = $_;
                $continuation =~ s/\\$/ /;
                next;
            }

            rstrip;

            # skip empty lines
            next
              if /^\s*$/;

            # skip comments
            next if /^[#\n]/;

            if (m/adduser .*--home +\/var\/run/) {
                $scripts_found{$file} = 1;
                next;
            }
        }

        close($fd);
    }

    $self->tag('adduser-with-home-var-run', $_) for sort keys %scripts_found;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

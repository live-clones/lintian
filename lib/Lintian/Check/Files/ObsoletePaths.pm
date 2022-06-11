# files/obsolete-paths -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2021 Felix Lechner
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

package Lintian::Check::Files::ObsoletePaths;

use v5.20;
use warnings;
use utf8;

use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has OBSOLETE_PATHS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %obsolete;

        my $data = $self->data->load('files/obsolete-paths',qr/\s*\->\s*/);

        for my $key ($data->all) {

            my $value = $data->value($key);

            my ($newdir, $moreinfo) = split(/\s*\~\~\s*/, $value, 2);

            $obsolete{$key} = {
                'newdir' => $newdir,
                'moreinfo' => $moreinfo,
                'match' => qr/$key/x,
                'olddir' => $key,
            };
        }

        return \%obsolete;
    }
);

sub visit_installed_files {
    my ($self, $item) = @_;

    # check for generic obsolete path
    for my $obsolete_path (keys %{$self->OBSOLETE_PATHS}) {

        my $obs_data = $self->OBSOLETE_PATHS->{$obsolete_path};
        my $oldpathmatch = $obs_data->{'match'};

        if ($item->name =~ m{$oldpathmatch}) {

            my $oldpath  = $obs_data->{'olddir'};
            my $newpath  = $obs_data->{'newdir'};
            my $moreinfo = $obs_data->{'moreinfo'};

            $self->pointed_hint('package-installs-into-obsolete-dir',
                $item->pointer,": $oldpath -> $newpath", $moreinfo);
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

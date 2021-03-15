# files/obsolete-paths -- lintian check script -*- perl -*-

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

        return $self->profile->load_data(
            'files/obsolete-paths',
            qr/\s*\->\s*/,
            sub {
                my @sliptline =  split(/\s*\~\~\s*/, $_[1], 2);

                if (scalar(@sliptline) != 2) {
                    die encode_utf8("Syntax error in files/obsolete-paths $.");
                }

                my ($newdir, $moreinfo) =  @sliptline;

                return {
                    'newdir' => $newdir,
                    'moreinfo' => $moreinfo,
                    'match' => qr/$_[0]/x,
                    'olddir' => $_[0],
                };
            });
    });

sub visit_installed_files {
    my ($self, $file) = @_;

    # check for generic obsolete path
    foreach my $obsolete_path ($self->OBSOLETE_PATHS->all) {

        my $obs_data = $self->OBSOLETE_PATHS->value($obsolete_path);
        my $oldpathmatch = $obs_data->{'match'};

        if ($file->name =~ m{$oldpathmatch}) {

            my $oldpath  = $obs_data->{'olddir'};
            my $newpath  = $obs_data->{'newdir'};
            my $moreinfo = $obs_data->{'moreinfo'};

            $self->hint('package-installs-into-obsolete-dir',
                $file->name,": $oldpath -> $newpath", $moreinfo);
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

# files/includes -- lintian check script -*- perl -*-

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

package Lintian::files::includes;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $MULTIARCH_DIRS = Lintian::Data->new('common/multiarch-dirs', qr/\s++/);
my $GENERIC_HEADER_FILES = Lintian::Data->new('files/generic-header-files');

has header_dirs => (is => 'rwp');

sub setup_installed_files {
    my ($self) = @_;

    my %header_dirs = ('usr/include/' => 1);

    foreach my $arch ($MULTIARCH_DIRS->all) {
        my $dir = $MULTIARCH_DIRS->value($arch);
        $header_dirs{"usr/include/$dir/"} = 1;
    }

    $self->_set_header_dirs(\%header_dirs);

    return;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    # only look at files in header locations
    return
      unless exists $self->header_dirs->{$file->dirname};

    if (   $file->is_file
        && $GENERIC_HEADER_FILES->matches_any($file->basename, 'i')) {

        $self->hint('header-has-overly-generic-name', $file->name);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

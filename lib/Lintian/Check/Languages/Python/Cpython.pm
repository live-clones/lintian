# languages/python/cpython -- lintian check script -*- perl -*-
#
# Copyright (C) 2022 Louis-Philippe Véronneau <pollo@debian.org>
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

package Lintian::Check::Languages::Python::Cpython;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    # Skip if there's no CPython extensions
    return
      unless $item->name
      =~ m{^usr/lib/python3/dist-packages/.+\.cpython-.+\.so$};

    my $SUPPORTED_VERSIONS = $self->data->load('python/versions', qr/\s*=\s*/);
    my @pyvers = split(qr{,},$SUPPORTED_VERSIONS->value('supported-versions'));
    my $extension = $item->name;

    for my $version (@pyvers) {
        $version =~ s/\.//;         # remove dot
        $extension =~ s/cpython-3\d\d-/cpython-$version-/;
        $self->hint('missing-cpython-extension', $extension)
          if !$self->processable->installed->resolve_path($extension);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

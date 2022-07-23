# languages/python/distutils -- lintian check script -*- perl -*-
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

package Lintian::Check::Languages::Python::Distutils;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $PYTHON3_DEPEND
  = 'python3:any | python3-dev:any | python3-all:any | python3-all-dev:any';

sub visit_patched_files {
    my ($self, $item) = @_;

    my $build_all = $self->processable->relation('Build-Depends-All');

    # Skip if the package doesn't depend on python
    return
      unless $build_all->satisfies($PYTHON3_DEPEND);

    # Skip if it's not a python file
    return
      unless $item->name =~ /\.py$/;

    # Skip if we can't open the file
    return
      unless $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        my $pointer = $item->pointer($position);

        $self->pointed_hint('uses-python-distutils', $pointer)
          if $line =~ m{^from distutils} || $line =~ m{^import distutils};
    } continue {
        ++$position;
    }

    close $fd;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

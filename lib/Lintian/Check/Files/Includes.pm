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

package Lintian::Check::Files::Includes;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw{any};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# case insensitive regular expressions for overly generic paths
const my @GENERIC_PATHS => ('^ util[s]? [.]h $');

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    my $consumed = $item->name;
    return
      unless $consumed =~ s{^usr/include/}{};

    my @multiarch_folders
      = values %{$self->profile->architectures->deb_host_multiarch};

    for my $tuple (@multiarch_folders) {

        last
          if $consumed =~ s{^$tuple/}{};
    }

    $self->hint('header-has-overly-generic-name', $item->name)
      if any { $consumed =~ m{ $_ }isx } @GENERIC_PATHS;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

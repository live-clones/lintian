# apt -- lintian check script -*- perl -*-

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

package Lintian::Check::Apt;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      if $self->processable->source_name eq 'apt';

    # /etc/apt/preferences
    $self->pointed_hint('package-installs-apt-preferences', $item->pointer)
      if $item->name =~ m{^ etc/apt/preferences (?: $ | [.]d / [^/]+ ) }x;

    # /etc/apt/sources
    unless ($self->processable->name =~ m{ -apt-source $}x) {

        $self->pointed_hint('package-installs-apt-sources', $item->pointer)
          if $item->name
          =~ m{^ etc/apt/sources[.]list (?: $ | [.]d / [^/]+ ) }x;
    }

    # /etc/apt/trusted.gpg
    unless (
        $self->processable->name=~ m{ (?: -apt-source | -archive-keyring ) $}x)
    {

        $self->pointed_hint('package-installs-apt-keyring', $item->pointer)
          if $item->name=~ m{^ etc/apt/trusted[.]gpg (?: $ | [.]d / [^/]+ ) }x;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# fields/version/repack/count -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2021 Kentaro Hayashi
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::Check::Fields::Version::Repack::Count;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    # repack counts in native packages are dealt with elsewhere
    return
      if $self->processable->native;

    my $fields = $self->processable->fields;

    return
      unless $fields->declares('Version');

    my $version = $fields->unfolded_value('Version');

    $self->hint('anticipated-repack-count', $version)
      if $version =~ m{ dfsg [01] - }x;

    $self->hint('dot-before-repack-count', $version)
      if $version =~ / dfsg [.] \d+ /x;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

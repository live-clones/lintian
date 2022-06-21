# fields/version -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
# Copyright (C) 2021 Felix Lechner
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

package Lintian::Check::Fields::Version;

use v5.20;
use warnings;
use utf8;

use Dpkg::Version;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    return
      unless $fields->declares('Version');

    my $version = $fields->unfolded_value('Version');

    my $dversion = Dpkg::Version->new($version);
    unless ($dversion->is_valid) {
        $self->hint('bad-version-number', $version);
        return;
    }

    my ($epoch, $upstream, $debian)
      = ($dversion->epoch, $dversion->version, $dversion->revision);

    # Dpkg::Version sets the debian revision to 0 if there is
    # no revision.  So we need to check if the raw version
    # ends with "-0".
    $self->hint('debian-revision-is-zero', $version)
      if $version =~ /-0$/;

    my $ubuntu;
    if($debian =~ /^(?:[^.]+)(?:\.[^.]+)?(?:\.[^.]+)?(\..*)?$/){
        my $extra = $1;
        if (
            defined $extra
            && $debian =~ m{\A
                            (?:[^.]+ubuntu[^.]+)(?:\.\d+){1,3}(\..*)?
                            \Z}xsm
        ) {
            $ubuntu = 1;
            $extra = $1;
        }

        $self->hint('debian-revision-not-well-formed', $version)
          if defined $extra;

    } else {
        $self->hint('debian-revision-not-well-formed', $version);
    }

    if ($self->processable->type eq 'source') {

        $self->hint('binary-nmu-debian-revision-in-source', $version)
          if ($debian =~ /^[^.-]+\.[^.-]+\./ && !$ubuntu)
          || $version =~ /\+b\d+$/;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

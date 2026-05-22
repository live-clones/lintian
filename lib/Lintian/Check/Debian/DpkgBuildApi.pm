# debian/dpkg-build-api -- lintian check script -*- perl -*-
#
# Copyright (C) 2025-2026 Nicholas Guriev <guriev-ns@ya.ru>
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

package Lintian::Check::Debian::DpkgBuildApi;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;
use Lintian::Relation;

with 'Lintian::Check';

sub source {
    my $self = shift;

    if (defined(my $level = $self->_level_from_dcontrol)) {
        my $dcontrol = $self->processable->debian_control;
        $self->pointed_hint('dpkg-build-api-level',
            $dcontrol->item->pointer, $level);
    } else {
        $self->hint('dpkg-build-api-level', 0);  # default level zero if unset
    }

    if (defined(my $pointer = $self->_level_from_drules)) {
        $self->pointed_hint('debian-rules-defines-dpkg-build-api', $pointer);
    }

    return;
}

########################### Private implementation. ###########################

# Looks through build dependencies at the dpkg-build-api virtual package.
# Returns version of the package if set in the debian/control file, otherwise
# returns undef.
sub _level_from_dcontrol {
    my $self = shift;

    my $build_prerequisites= $self->processable->relation('Build-Depends-All');

    my $virtual_build_api;
    $build_prerequisites->visit(
        sub {
            return 0 unless /^dpkg-build-api(?::\S+)?\s*[(]=\s*(\d+)[)]$/;
            $virtual_build_api = $1;
            return 1;
        },
        Lintian::Relation::VISIT_PRED_FULL
          | Lintian::Relation::VISIT_STOP_FIRST_MATCH
    );

    return $virtual_build_api;
}

# Parses the debian/rules script seeking value of the DPKG_BUILD_API variable
# and returns pointer to the line where it is defined if any. The variable
# should not be concealed under conditional to preclude false positives.
sub _level_from_drules {
    my $self = shift;
    my $varname = 'DPKG_BUILD_API';

    my $drules = $self->processable->patched->resolve_path('debian/rules');
    return undef unless $drules and $drules->is_open_ok;

    open(my $rules_fd, '<', $drules->unpacked_path)
      or die encode_utf8('Cannot open ' . $drules->unpacked_path);

    my ($position, $maybe_skipping, $numline);
    while (my $line = <$rules_fd>) {
        $numline++;
        while ($line =~ s/\\$// and defined(my $cont = <$rules_fd>)) {
            $numline++;
            $line .= $cont;
        }
        next if $line =~ /^\s*\#/;

        if ($line =~ /^\s*ifn?(?:eq|def)\b/) {
            $maybe_skipping++;
        } elsif ($line =~ /^\s*endif\b/) {
            $maybe_skipping--;
        }
        next if $maybe_skipping;

        if (
            $line =~ m{
                ^
                \s*(?: export \s+ | override \s+ )? $varname
                \s*(?: = | := | ::= | \?= | \+= | != )
            |
                ^
                \s*(?: export \s+ | override \s+ )? define \s+ $varname
            }x
        ) {
            $position = $numline;
            last;
        }
    }
    close $rules_fd;

    return $position ? $drules->pointer($position) : undef;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

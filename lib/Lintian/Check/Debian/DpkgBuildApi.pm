# debian/dpkg-build-api -- lintian check script -*- perl -*-
#
# Copyright (C) 2025 Nicholas Guriev <guriev-ns@ya.ru>
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

with 'Lintian::Check';

sub source {
    my $self = shift;

    my ($parsed, $level_from_drules, $pointer) = $self->_level_from_drules;
    return unless $parsed;
    my $level_from_dcontrol = $self->_level_from_dcontrol;

    if (defined $level_from_drules and defined $level_from_dcontrol
            and $level_from_drules ne $level_from_dcontrol) {
        $self->pointed_hint(
            'debian-rules-overrides-dpkg-build-api', $pointer,
            $level_from_drules, '!=', $level_from_dcontrol);
    } elsif (defined $level_from_drules or defined $level_from_dcontrol) {
        my $level = $level_from_drules // $level_from_dcontrol;
        $pointer //= $self->processable->debian_control->item->pointer;
        $self->pointed_hint('dpkg-build-api-level', $pointer, $level);
    } else {
        $self->hint('dpkg-build-api-level', 0);  # default level zero if unset
    }
}

############################ Private implementation. ###########################

=item _level_from_dcontrol()

Looks through build dependencies at the dpkg-build-api virtual package. Returns
version of the package if set in the debian/control file, otherwise returns
undef.

=cut

sub _level_from_dcontrol {
    my $self = shift;

    my $build_prerequisites = $self->processable->relation('Build-Depends-All');

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

=item _level_from_drules()

Parses the debian/rules script seeking value of the DPKG_BUILD_API variable. The
variable must be exported in order to be effective. Returns up to three
parameters ($parsed, $level, $pointer).

$parsed - boolean flag is true if and only if the script was parsed without
ambiguity and no conditional or substitution encountered on the variable
$level - value of the variable if set or undef
$pointer - filename and line number where the variable set

=cut

sub _level_from_drules {
    my $self = shift;
    my $varname = 'DPKG_BUILD_API';

    my $drules = $self->processable->patched->resolve_path('debian/rules');
    return undef unless $drules and $drules->is_open_ok;

    open(my $rules_fd, '<', $drules->unpacked_path)
        or die encode_utf8('Cannot open ' . $drules->unpacked_path);

    my (
        $variable_build_api, $position, $exported, $uncertain, $maybe_skipping,
        $numline,
    );
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

        if ($line =~ m{
            ^
            \s*(?:export\s+)? $varname
            \s*(?: = | := | ::= | \?= )
            \s*(\S+)
        }x) {
            if ($1 =~ /\$[^\$]/ or $maybe_skipping) {
                $uncertain = 1;
                last;
            }
            $variable_build_api = $1;
            $position = $numline;
        }
        if ($line =~ /^\s*(un)?export\s+ (?:[^:#=\s]+\s+)* $varname\b /x) {
            if ($1 or $maybe_skipping) {
                $uncertain = 1;
                last;
            }
            $exported = 1;
        }
        if ($line =~ /^\s*export\s*$/ and not $maybe_skipping) {
            $exported = 1;
        }
    }
    close $rules_fd;

    return undef if $uncertain;
    return 'ok' unless $exported and defined $variable_build_api;
    ('ok', $variable_build_api, $drules->pointer($position));
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

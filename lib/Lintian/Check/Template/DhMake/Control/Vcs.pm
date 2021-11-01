# template/dh-make/control/vcs -- lintian check script -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Check::Template::DhMake::Control::Vcs;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $file = $self->processable->patched->resolve_path('debian/control');
    return
      unless $file;

    my @lines = split(/\n/, $file->decoded_utf8);

    my $line;
    my $position = 1;
    while (defined($line = shift @lines)) {

        $line =~ s{\s*$}{};

        if (
            $line =~ m{\A \# \s* Vcs-(?:Git|Browser): \s*
                       (?:git|http)://git\.debian\.org/
                       (?:\?p=)?collab-maint/<pkg>\.git}smx
        ) {

            $self->hint('control-file-contains-dh-make-vcs-comment',
                $line, "[debian/control:$position]");

            # once per source
            last;
        }

    } continue {
        ++$position;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

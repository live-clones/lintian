# debian/not-installed -- lintian check script -*- perl -*-

# Copyright © 2020 Felix Lechner
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

package Lintian::Check::Debian::NotInstalled;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $ARCHITECTURE_TRIPLET => qr{[^/-]+-[^/-]+-[^/-]+};

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $not_installed
      = $processable->patched->resolve_path('debian/not-installed');
    return
      unless defined $not_installed;

    my $contents = $not_installed->bytes;

    # strip comments
    $contents =~ s/^\h#.*\R?//mg;

    my @lines = split(/\n/, $contents);

    my @usr_lib_triplet = grep { m{^usr/lib/$ARCHITECTURE_TRIPLET/} } @lines;
    my @too_specific = grep { !m{^usr/lib/\*/} } @usr_lib_triplet;

    $self->hint('unwanted-path-too-specific', $_) for @too_specific;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# languages/clojure/dh-clojure -- lintian check script -*- perl -*-
#
# Copyright (C) 2026 Louis-Philippe Véronneau <pollo@debian.org>
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

package Lintian::Check::Languages::Clojure::DhClojure;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    # Skip if it isn't a Clojure package
    return
      unless $self->processable->name =~ /-clojure$/;

    my $build_all = $self->processable->relation('Build-Depends-All');

    # For now, only target packages using lein, as dh-clojure doesn't yet
    # support other build systems
    $self->hint('clojure-package-but-not-dh-clojure')
      unless $build_all->satisfies('leiningen')
      && $build_all->satisfies('dh-clojure');

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

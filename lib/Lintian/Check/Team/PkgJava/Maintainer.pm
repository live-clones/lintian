# team/pkg-java/maintainer -- lintian checks for Maintainer headers -*- perl -*-
#
# Copyright © 2021 Louis-Philippe Véronneau <pollo@debian.org>
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

package Lintian::Check::Team::PkgJava::Maintainer;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    # only for packages in the Java Team
    my $maintainer = $fields->value('Maintainer');
    return
      unless $maintainer=~ m{pkg-java-maintainers\@lists\.alioth\.debian\.org};

    # required in source packages, but dpkg-source already refuses to unpack
    # without this field (and fields depends on unpacked)
    return
      unless $fields->declares('Source');

    my $source = $fields->unfolded_value('Source');

    $self->hint('clojure-package-in-java-team')
      if $source =~ m{-clojure};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

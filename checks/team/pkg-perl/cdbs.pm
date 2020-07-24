# team/pkg-perl/debhelper -- lintian check script for required cdbs versions -*- perl -*-
#
# Copyright © 2013 Niels Thykier <niels@thykier.net>
# Copyright © 2013 gregor herrmann <gregoa@debian.org>
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

package Lintian::team::pkg_perl::cdbs;

use v5.20;
use warnings;
use utf8;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    # only for pkg-perl packages
    my $maintainer = $self->processable->fields->value('Maintainer');
    return
      unless $maintainer=~ /pkg-perl-maintainers\@lists\.alioth\.debian\.org/;

    # only for cdbs packages
    my $build_depends_all = $self->processable->relation('Build-Depends-All');
    return
      unless $build_depends_all->implies('cdbs');

    my $build_depends = $self->processable->relation('Build-Depends');

    unless ($build_depends->implies('cdbs (>= 0.4.122~)')) {

        # arch:any and cdbs version 0.4.122
        $self->tag('arch-any-package-needs-newer-cdbs')
          unless $self->processable->fields->value('Architecture') eq 'all';

        # Module::Build::Tiny and cdbs version 0.4.122
        $self->tag('module-build-tiny-needs-newer-cdbs')
          if $build_depends_all->implies('libmodule-build-tiny-perl');
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

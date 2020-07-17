# team/pkg-js/debhelper -- lintian check script for checking Vcs-* headers -*- perl -*-
#
# Copyright © 2013 Niels Thykier <niels@thykier.net>
# Copyright © 2013 gregor herrmann <gregoa@debian.org>
# Copyright © 2013 Axel Beckert <abe@debian.org>
# Copyright © 2019 Xavier Guimard <yadd@debian.org>
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

package Lintian::team::pkg_js::vcs;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @NON_GIT_VCS_FIELDS
  = qw(Vcs-Arch Vcs-Bzr Vcs-Cvs Vcs-Darcs Vcs-Hg Vcs-Mtn Vcs-Svn);
my @VCS_FIELDS = (@NON_GIT_VCS_FIELDS, qw(Vcs-Git Vcs-Browser));

sub source {
    my ($self) = @_;

    # only for pkg-perl packages
    my $maintainer = $self->processable->fields->value('Maintainer');
    return
      unless $maintainer
      =~ /pkg-javascript-maintainers\@lists\.alioth\.debian\.org/;

    my @non_git = $self->processable->fields->present(@NON_GIT_VCS_FIELDS);
    $self->tag('no-git', $_) for @non_git;

    # check for team locations
    for my $name (@VCS_FIELDS) {

        next
          unless $self->processable->fields->exists($name);

        my $value = $self->processable->fields->value($name);

        # get actual capitalization
        my $original_name = $self->processable->fields->literal_name($name);

        $self->tag('no-team-url', $original_name, $value)
          unless $value=~ m{^https://salsa.debian.org/js-team}i;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

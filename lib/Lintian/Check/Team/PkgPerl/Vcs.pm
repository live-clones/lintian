# team/pkg-perl/debhelper -- lintian check script for checking Vcs-* headers -*- perl -*-
#
# Copyright © 2013 Niels Thykier <niels@thykier.net>
# Copyright © 2013 gregor herrmann <gregoa@debian.org>
# Copyright © 2013 Axel Beckert <abe@debian.org>
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

package Lintian::Check::Team::PkgPerl::Vcs;

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

    my $fields = $self->processable->fields;

    # only for pkg-perl packages
    my $maintainer = $fields->value('Maintainer');
    return
      unless $maintainer=~ /pkg-perl-maintainers\@lists\.alioth\.debian\.org/;

    my @non_git = grep { $fields->declares($_) } @NON_GIT_VCS_FIELDS;
    $self->hint('no-git', $_) for @non_git;

    # check for team locations
    for my $name (@VCS_FIELDS) {

        next
          unless $fields->declares($name);

        my $value = $fields->value($name);

        # get actual capitalization
        my $original_name = $fields->literal_name($name);

        $self->hint('no-team-url', $original_name, $value)
          unless $value
          =~ m{^https://salsa\.debian\.org/perl-team/modules/packages}i;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

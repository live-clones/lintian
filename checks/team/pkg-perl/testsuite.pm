# team/pkg-perl/no-testsuite -- lintian check script for detecting a missing Testsuite header -*- perl -*-
#
# Copyright © 2013 Niels Thykier <niels@thykier.net>
# Copyright © 2013 gregor herrmann <gregoa@debian.org>
# Copyright © 2014 Niko Tyni <ntyni@debian.org>
# Copyright © 2018 Florian Schlichting <fsfs@debian.org>
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

package Lintian::team::pkg_perl::testsuite;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $maintainer = $self->processable->field('Maintainer');
    return
      unless length $maintainer;

    # only for pkg-perl packages
    return
      unless $maintainer=~ /pkg-perl-maintainers\@lists\.alioth\.debian\.org/;

    my $testsuite = $self->processable->field('Testsuite');
    unless (defined $testsuite) {

        $self->tag('no-testsuite-header');
        return;
    }

    unless ($testsuite eq 'autopkgtest-pkg-perl') {

        $self->tag('no-team-tests', $testsuite);
        return;
    }

    my $metajson = $self->processable->patched->lookup('META.json');
    my $metayml = $self->processable->patched->lookup('META.yml');

    $self->tag('autopkgtest-needs-use-name')
      unless (defined $metajson && $metajson->size)
      || (defined $metayml && $metayml->size)
      || $self->processable->patched->lookup('debian/tests/pkg-perl/use-name');

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

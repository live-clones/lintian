# team/pkg-js/testsuite -- lintian check script for detecting a missing Testsuite header -*- perl -*-
#
# Copyright © 2013 Niels Thykier <niels@thykier.net>
# Copyright © 2013 gregor herrmann <gregoa@debian.org>
# Copyright © 2014 Niko Tyni <ntyni@debian.org>
# Copyright © 2018 Florian Schlichting <fsfs@debian.org>
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

package Lintian::Check::Team::PkgJs::Testsuite;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $maintainer = $self->processable->fields->value('Maintainer');

    # only for pkg-perl packages
    return
      unless $maintainer
      =~ /pkg-javascript-maintainers\@lists\.alioth\.debian\.org/;

    unless ($self->processable->fields->declares('Testsuite')) {

        $self->hint('no-testsuite-header');
        return;
    }

    my @testsuites
      = $self->processable->fields->trimmed_list('Testsuite', qr/,/);

    if (none { $_ eq 'autopkgtest-pkg-perl' } @testsuites) {

        $self->hint('no-team-tests');
        return;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# languages/r/site-library -- lintian check script -*- perl -*-

# Copyright © 2020 Dylan Aïssi
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

package Lintian::Check::Languages::R::SiteLibrary;

use v5.20;
use warnings;
use utf8;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has r_site_libraries => (is => 'rw', default => sub { [] });

sub visit_installed_files {
    my ($self, $file) = @_;

    # R site libraries
    if ($file->name =~ m{^usr/lib/R/site-library/(.*)/DESCRIPTION$}) {
        push(@{$self->r_site_libraries}, $1);
    }

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint('ships-r-site-library', $_) for @{$self->r_site_libraries};

    return
      unless @{$self->r_site_libraries};

    my $depends = $self->processable->relation('strong');

    # no version allowed for virtual package; no alternatives
    $self->hint('requires-r-api')
      unless $depends->matches(qr/^r-api-[\w\d+-.]+$/,
        Lintian::Relation::VISIT_OR_CLAUSE_FULL);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

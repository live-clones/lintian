# team/pkg-js/deprecated -- lintian check script for deprecated javascript -*- perl -*-
#
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

package Lintian::Check::Team::PkgJs::Deprecated;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has javascript_team_maintained => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($boolean) = @_; return ($boolean // 0); },
    default => sub {
        my ($self) = @_;

        my $maintainer = $self->processable->fields->value('Maintainer');

        # only for pkg-perl packages
        return 1
          if $maintainer
          =~ /pkg-javascript-maintainers\@lists\.alioth\.debian\.org/;

        return 0;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $self->javascript_team_maintained;

    return
      unless $item->name =~ /\.js$/;

    my $bytes = $item->bytes;
    return
      unless length $bytes;

    $self->hint('nodejs-bad-buffer-usage')
      if $bytes =~ /\bnew\s+Buffer\(/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

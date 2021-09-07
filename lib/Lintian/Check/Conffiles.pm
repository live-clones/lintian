# conffiles -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2000 Sean 'Shaleh' Perry
# Copyright © 2017 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Conffiles;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any none);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      if $self->processable->type =~ 'udeb';

    my $conffiles = $self->processable->conffiles;

    unless ($item->is_file) {
        $self->hint('conffile-has-bad-file-type', $item)
          if $conffiles->is_known($item->name);
        return;
    }

    # files /etc must be conffiles, with some exceptions).
    $self->hint('file-in-etc-not-marked-as-conffile', $item)
      if $item->name =~ m{^etc/}
      && !$conffiles->is_known($item->name)
      && $item->name !~ m{/README$}
      && $item->name !~ m{^ etc/init[.]d/ (?: skeleton | rc S? ) $}x;

    $self->hint('file-in-etc-rc.d-marked-as-conffile', $item)
      if $conffiles->is_known($item->name)
      && $item->name =~ m{^etc/rc.\.d/};

    if ($conffiles->is_known($item->name) && $item->name !~ m{^etc/}) {

        if ($item->name =~ m{^usr/}) {
            $self->hint('file-in-usr-marked-as-conffile', $item);

        } else {
            $self->hint('non-etc-file-marked-as-conffile', $item);
        }
    }

    return;
}

sub binary {
    my ($self) = @_;

    my $conffiles = $self->processable->conffiles;

    for my $relative ($conffiles->all) {

        my @instructions = @{$conffiles->instructions->{$relative}};
        my $should_exist = none { $_ eq 'remove-on-upgrade' } @instructions;
        my $may_not_exist = any { $_ eq 'remove-on-upgrade' } @instructions;

        my $shipped = $self->processable->installed->lookup($relative);

        $self->hint('missing-conffile', $relative)
          if $should_exist && !defined $shipped;

        $self->hint('unexpected-conffile', $relative)
          if $may_not_exist && defined $shipped;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# debian/rules/dh-sequencer -- lintian check script -*- perl -*-

# Copyright © 2019 Felix Lechner
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

package Lintian::debian::rules::dh_sequencer;

use strict;
use warnings;

use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;
    my $group = $self->group;

    my $debian_dir = $processable->index_resolved_path('debian');
    return
      unless $debian_dir;

    my $rules = $debian_dir->child('rules');
    return
      unless $rules;

    return
      unless $rules->is_open_ok;

    my $contents = path($rules->fs_path)->slurp;

    $self->tag('no-dh-sequencer')
      unless $contents =~ /^\%:[^ \t]*\n\t+dh[ \t]+\$\@/m
      || $contents =~ m{^\s*include\s+/usr/share/cdbs/1/class/hlibrary.mk\s*$}m
      || $contents =~ m{\bDEB_CABAL_PACKAGE\b};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

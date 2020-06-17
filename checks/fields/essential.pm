# fields/essential -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::fields::essential;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Data ();

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $KNOWN_ESSENTIAL = Lintian::Data->new('fields/essential');

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $essential = $processable->unfolded_field('Essential');
    return
      unless defined $essential;

    $self->tag('essential-in-source-package');

    return;
}

sub always {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    my $essential = $processable->unfolded_field('Essential');
    return
      unless defined $essential;

    unless ($essential eq 'yes' || $essential eq 'no') {
        $self->tag('unknown-essential-value');
        return;
    }

    $self->tag('essential-no-not-needed') if $essential eq 'no';

    $self->tag('new-essential-package')
      if $essential eq 'yes' && !$KNOWN_ESSENTIAL->known($pkg);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

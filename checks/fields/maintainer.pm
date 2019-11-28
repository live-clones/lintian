# fields/maintainer -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
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

package Lintian::fields::maintainer;

use strict;
use warnings;
use autodie;

use Lintian::Maintainer qw(check_maintainer);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $maintainer = $processable->unfolded_field('maintainer');

    return
      unless defined $maintainer;

    my $is_list = $maintainer =~ /\@lists(?:\.alioth)?\.debian\.org\b/;

    $self->tag('no-human-maintainers')
      if $is_list && !defined $processable->field('uploaders');

    return;
}

sub always {
    my ($self) = @_;

    my $processable = $self->processable;

    my $maintainer = $processable->unfolded_field('maintainer');

    unless (defined $maintainer) {
        $self->tag('no-maintainer-field');
        return;
    }

    my @tags = check_maintainer($maintainer, 'maintainer');
    $self->tag(@{$_}) for @tags;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

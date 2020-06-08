# fields/terminal-control -- lintian check script -*- perl -*-
#
# Copyright © 2020 Felix Lechner
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

package Lintian::fields::terminal_control;

use v5.20;
use warnings;
use utf8;
use autodie;

use constant ESCAPE => qq{\033};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my @names = keys %{$self->processable->field};

    for my $name (@names) {

        my $value = $self->processable->field($name);

        return
          unless length $value;

        # title-case the field name
        (my $label = $name) =~ s/\b(\w)/\U$1/g;

        # check if field contains and ESC character
        $self->tag('ansi-escape', $label, $value)
          if index($value, ESCAPE) >= 0;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
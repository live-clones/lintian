# fields/priority -- lintian check script (rewrite) -*- perl -*-
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

package Lintian::Check::Fields::Priority;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    return
      unless $fields->declares('Priority');

    my $priority = $fields->unfolded_value('Priority');

    if ($self->processable->type eq 'source'
        || !$self->processable->is_auto_generated) {

        $self->hint('priority-extra-is-replaced-by-priority-optional')
          if $priority eq 'extra';

        # Re-map to optional to avoid an additional warning from
        # lintian
        $priority = 'optional'
          if $priority eq 'extra';
    }

    my $KNOWN_PRIOS = $self->profile->load_data('fields/priorities');

    $self->hint('unknown-priority', $priority)
      unless $KNOWN_PRIOS->recognizes($priority);

    $self->hint('excessive-priority-for-library-package', $priority)
      if $self->processable->name =~ /^lib/
      && $self->processable->name !~ /-bin$/
      && $self->processable->name !~ /^libc[0-9.]+$/
      && (
        any { $_ eq $self->processable->fields->value('Section') }
        qw(libdevel libs)
      )&& (any { $_ eq $priority } qw(required important standard));

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

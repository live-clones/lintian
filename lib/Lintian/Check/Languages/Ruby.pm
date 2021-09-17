# languages/ruby -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Languages::Ruby;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $fields = $self->processable->fields;
    if ($fields->declares('Homepage')) {

        my $homepage = $fields->value('Homepage');

        # rubygems itself is okay; see Bug#981935
        $self->hint('rubygem-homepage', $homepage)
          if $homepage
          =~ m{^http s? :// (?:www [.])? rubygems [.] org/gems/}isx;
    }

    return;
}

sub binary {
    my ($self) = @_;

    my @prerequisites
      = $self->processable->fields->trimmed_list('Depends', qr/,/);

    my @ruby_interpreter = grep { / \b ruby-interpreter \b /x } @prerequisites;

    $self->hint('ruby-interpreter-is-deprecated', $_)for @ruby_interpreter;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

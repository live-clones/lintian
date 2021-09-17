# fields/format -- lintian check script (rewrite) -*- perl -*-
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

package Lintian::Check::Fields::Format;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @supported_source_formats = (qr/1\.0/, qr/3\.0\s*\((quilt|native)\)/);

sub source {
    my ($self) = @_;

    return
      unless $self->processable->fields->declares('Format');

    my $format = $self->processable->fields->unfolded_value('Format');

    my $supported = 0;
    for my $f (@supported_source_formats){

        $supported = 1
          if $format =~ /^\s*$f\s*\z/;
    }

    $self->hint('unsupported-source-format', $format) unless $supported;

    return;
}

sub changes {
    my ($self) = @_;

    my $format = $self->processable->fields->unfolded_value('Format');

    # without a Format field something is wrong
    unless (length $format) {
        $self->hint('malformed-changes-file');
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

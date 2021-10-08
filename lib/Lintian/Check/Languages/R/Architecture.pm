# languages/r/architecture -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
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

package Lintian::Check::Languages::R::Architecture;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has have_r_files => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      if $file->is_dir;

    $self->have_r_files(1)
      if $file->name =~ m{^usr/lib/R/.*/DESCRIPTION$}
      && $file->decoded_utf8 =~ /^NeedsCompilation: no/m;

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint('r-package-not-arch-all')
      if $self->processable->name =~ /^r-(?:cran|bioc|other)-/
      && $self->have_r_files
      && $self->processable->fields->value('Architecture') ne 'all';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

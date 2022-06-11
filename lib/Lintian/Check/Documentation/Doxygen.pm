# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIES
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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

package Lintian::Check::Documentation::Doxygen;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    $self->pointed_hint('source-contains-prebuilt-doxygen-documentation',
        $item->parent_dir->pointer)
      if $item->basename =~ m{^doxygen.(?:png|sty)$}
      && $self->processable->source_name ne 'doxygen';

    return
      unless $item->basename =~ /\.(?:x?html?\d?|xht)$/i;

    my $contents = $item->decoded_utf8;
    return
      unless length $contents;

    my $lowercase = lc($contents);

    # Identify and ignore documentation templates by looking
    # for the use of various interpolated variables.
    # <http://www.doxygen.nl/manual/config.html#cfg_html_header>
    $self->pointed_hint('source-contains-prebuilt-doxygen-documentation',
        $item->pointer)
      if $lowercase =~ m{<meta \s+ name="generator" \s+ content="doxygen}smx
      && $lowercase
      !~ /\$(?:doxygenversion|projectname|projectnumber|projectlogo)\b/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

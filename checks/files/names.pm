# files/names -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::names;

use strict;
use warnings;
use autodie;

use Moo;

use Lintian::Util qw(is_string_utf8_encoded);

with('Lintian::Check');

my $FNAMES = Lintian::Data->new('files/fnames', qr/\s*\~\~\s*/);

my %PATH_DIRECTORIES = map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin/ usr/games/ );

sub files {
    my ($self, $file) = @_;

    # unusual characters
    if ($file->name =~ m,\s+\z,) {
        $self->tag('file-name-ends-in-whitespace', $file->name);
    }
    if ($file->name =~ m,/\*\z,) {
        $self->tag('star-file', $file->name);
    }
    if ($file->name =~ m,/-\z,) {
        $self->tag('hyphen-file', $file->name);
    }

    # check for generic bad filenames
    foreach my $tag ($FNAMES->all()) {

        my $regex = $FNAMES->value($tag);

        $self->tag($tag, $file->name)
          if $file->name =~ m/$regex/;
    }

    if (exists($PATH_DIRECTORIES{$file->dirname})) {

        $self->tag('file-name-in-PATH-is-not-ASCII', $file->name)
          if $file->basename !~ m{\A [[:ascii:]]++ \Z}xsm;

        $self->tag('zero-byte-executable-in-path', $file->name)
          if $file->is_regular_file
          and $file->is_executable
          and $file->size == 0;

    } elsif (!is_string_utf8_encoded($file->name)) {
        $self->tag('file-name-is-not-valid-UTF-8', $file->name);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# files/compressed -- lintian check script -*- perl -*-

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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Files::Compressed;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $VERTICAL_BAR => q{|};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# an OR (|) regex of all compressed extension
has COMPRESS_FILE_EXTENSIONS_OR_ALL => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $COMPRESS_FILE_EXTENSIONS
          = $self->data->load('files/compressed-file-extensions',qr/\s+/);

        my $text = join($VERTICAL_BAR,
            map { quotemeta }$COMPRESS_FILE_EXTENSIONS->all);

        return qr/$text/;
    }
);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    my $regex = $self->COMPRESS_FILE_EXTENSIONS_OR_ALL;

    # see tag duplicated-compressed-file
    my $DUPLICATED_COMPRESSED_FILE_REGEX= qr/^(.+)\.$regex$/;

    # both compressed and uncompressed present
    if ($item->name =~ $DUPLICATED_COMPRESSED_FILE_REGEX) {

        $self->pointed_hint('compressed-duplicate', $item->pointer)
          if $self->processable->installed->lookup($1);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

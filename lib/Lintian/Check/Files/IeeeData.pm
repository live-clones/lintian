# files/ieee-data -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::IeeeData;

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

    my $regex = $self->COMPRESS_FILE_EXTENSIONS_OR_ALL;

    if (   $item->is_regular_file
        && $item->name
        =~ m{/(?:[^/]-)?(?:oui|iab)(?:\.(txt|idx|db))?(?:\.$regex)?\Z}x) {

        # see #785662
        if ($item->name =~ / oui /msx || $item->name =~ / iab /msx) {

            $self->pointed_hint('package-installs-ieee-data', $item->pointer)
              unless $self->processable->source_name eq 'ieee-data';
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

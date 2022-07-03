# files/contents/line-length -- lintian check script -*- perl -*-

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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Files::Contents::LineLength;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::UtilsBy qw(max_by);
use Unicode::UTF8 qw(encode_utf8 decode_utf8 valid_utf8);

const my $GREATER_THAN => q{>};
const my $VERTICAL_BAR => q{|};

const my $VERY_LONG => 512;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# an OR (|) regex of all compressed extension
has BINARY_FILE_EXTENSIONS_OR_ALL => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $BINARY_FILE_EXTENSIONS
          = $self->data->load('files/binary-file-extensions',qr/\s+/);
        my $COMPRESSED_FILE_EXTENSIONS
          = $self->data->load('files/compressed-file-extensions',qr/\s+/);

        my $text = join(
            $VERTICAL_BAR,
            (
                map { quotemeta } $BINARY_FILE_EXTENSIONS->all,
                $COMPRESSED_FILE_EXTENSIONS->all
            )
        );

        return qr/$text/i;
    }
);

sub visit_patched_files {
    my ($self, $item) = @_;

    # Skip if no regular file
    return
      unless $item->is_regular_file;

    # Skip if file has a known binary, XML or JSON suffix.
    my $pattern = $self->BINARY_FILE_EXTENSIONS_OR_ALL;
    return
      if $item->basename
      =~ qr{ [.] ($pattern | xml | sgml | svg | jsonl?) \s* $}x;

    # Skip if we can't open it.
    return
      unless $item->is_open_ok;

    # Skip if file is detected to be an image or JSON.
    return
      if $item->file_type =~ m{image|bitmap|JSON};

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my %line_lengths;

    my $position = 1;
    while (my $line = <$fd>) {
        # Skip SQL insert and select statements
        next if ($line =~ /^(INSERT|SELECT)\s/i
            and $item->basename =~ /sql/i);

        # count codepoints, if possible
        $line = decode_utf8($line)
          if valid_utf8($line);

        $line_lengths{$position} = length $line;

    } continue {
        ++$position;
    }

    close $fd;

    my $longest = max_by { $line_lengths{$_} } keys %line_lengths;

    return
      unless defined $longest;

    my $pointer = $item->pointer($longest);

    $self->pointed_hint('very-long-line-length-in-source-file',
        $pointer, $line_lengths{$longest}, $GREATER_THAN, $VERY_LONG)
      if $line_lengths{$longest} > $VERY_LONG;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

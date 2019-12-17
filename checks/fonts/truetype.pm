# fonts/truetype -- lintian check script -*- perl -*-

# Copyright © Felix Lechner
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

package Lintian::fonts::truetype;

use strict;
use warnings;

use Font::TTF::Font;

use constant SPACE => q{ };
use constant COMMA => q{,};
use constant LSQUARE => q{[};
use constant RSQUARE => q{]};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    return
      unless $file->file_info =~ /^TrueType Font data/;

    $self->tag('truetype-font-wrong-filename', $file->name)
      unless $file->name =~ /\.ttf$/i;

    my $font = Font::TTF::Font->open($file->fs_path);
    return
      unless $font;

    my $table = $font->{'OS/2'}->read;
    return
      unless $table;

    my $fsType = $table->{fsType};
    if (defined $fsType) {

        my $permissions = $fsType & 0x00f;
        my @clauses;
        push(@clauses, 'never embed')
          if $permissions & 0x02;
        push(@clauses, 'preview/print only')
          if $permissions & 0x04;
        push(@clauses, 'edit only')
          if $permissions & 0x08;

        my $terms = join(COMMA . SPACE, @clauses);
        $terms = LSQUARE . $terms . RSQUARE
          if @clauses > 0;

        $self->tag('truetype-font-prohibits-installable-embedding',
            $terms . SPACE . $file->name)
          if $terms;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
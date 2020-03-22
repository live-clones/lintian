# fonts/truetype -- lintian check script -*- perl -*-

# Copyright © 2019 Felix Lechner
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
use autodie qw(open);

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

    my $font = Font::TTF::Font->open($file->unpacked_path);

    my $os2 = defined $font ? $font->{'OS/2'} : undef;
    my $table = defined $os2 ? $os2->read : undef;
    my $fsType = defined $table ? $table->{fsType} : undef;

    $font->release
      if defined $font;

    return
      unless defined $fsType;

    my @clauses;

    my $permissions = $fsType & 0x00f;
    push(@clauses, 'never embed')
      if $permissions & 0x02;
    push(@clauses, 'preview/print only')
      if $permissions & 0x04;
    push(@clauses, 'edit only')
      if $permissions & 0x08;

    my $terms;
    $terms = join(COMMA . SPACE, @clauses)
      if @clauses;

    $self->tag('truetype-font-prohibits-installable-embedding',
        "[$terms] " . $file->name)
      if length $terms;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

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

package Lintian::Check::Fonts::Truetype;

use v5.20;
use warnings;
use utf8;
use autodie qw(open);

use Const::Fast;
use Font::TTF::Font;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };
const my $COMMA => q{,};

const my $PERMISSIONS_MASK => 0x0f;
const my $NEVER_EMBED_FLAG => 0x02;
const my $PRINT_PREVIEW_ONLY_FLAG => 0x04;
const my $EDIT_ONLY_FLAG => 0x08;

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    return
      unless $file->file_info =~ /^TrueType Font data/;

    $self->hint('truetype-font-wrong-filename', $file->name)
      unless $file->name =~ /\.ttf$/i;

    my $font = Font::TTF::Font->open($file->unpacked_path);

    my $os2 = defined $font ? $font->{'OS/2'} : undef;
    my $table = defined $os2 ? $os2->read : undef;
    my $fs_type = defined $table ? $table->{fsType} : undef;

    $font->release
      if defined $font;

    return
      unless defined $fs_type;

    my @clauses;

    my $permissions = $fs_type & $PERMISSIONS_MASK;
    push(@clauses, 'never embed')
      if $permissions & $NEVER_EMBED_FLAG;
    push(@clauses, 'preview/print only')
      if $permissions & $PRINT_PREVIEW_ONLY_FLAG;
    push(@clauses, 'edit only')
      if $permissions & $EDIT_ONLY_FLAG;

    my $terms;
    $terms = join($COMMA . $SPACE, @clauses)
      if @clauses;

    $self->hint('truetype-font-prohibits-installable-embedding',
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

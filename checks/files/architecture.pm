# files/architecture -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::architecture;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $TRIPLETS = Lintian::Data->new('files/triplets', qr/\s++/);

has arch_dep_files => (is => 'rwp', default => 0);

sub files {
    my ($self, $file) = @_;

    my $architecture = $self->processable->field('architecture', '');

    if ($file->name =~ m,^(?:usr/)?lib/([^/]+)/$,) {
        my $subdir = $1;
        if ($TRIPLETS->known($subdir)) {

            $self->tag('triplet-dir-and-architecture-mismatch',
                $file->name, 'is for',$TRIPLETS->value($subdir))
              unless ($architecture eq $TRIPLETS->value($subdir));
        }
    }

    $self->_set_arch_dep_files(1)
      if not $file->is_dir
      and $file->name !~ m,^usr/share/,
      and $file->file_info
      and $file->file_info !~ m/\bASCII text\b/;

    if ($file->dirname =~ m,^(?:usr)?/lib/([^/]+)/$,) {
        $self->_set_arch_dep_files(1)
          if $TRIPLETS->known($1 // '');
    }

    return;
}

sub breakdown {
    my ($self) = @_;

    my $architecture = $self->processable->field('architecture', '');

    # check if package is empty
    my $is_dummy = $self->processable->is_pkg_class('any-meta');

    $self->tag('package-contains-no-arch-dependent-files')
      unless $is_dummy
      || $self->arch_dep_files
      || $architecture eq 'all'
      || $self->type eq 'udeb';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

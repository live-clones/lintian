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

package Lintian::Check::files::architecture;

use v5.20;
use warnings;
use utf8;
use autodie;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

has TRIPLETS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/triplets', qr/\s++/);
    });

has arch_dep_files => (is => 'rwp', default => 0);

sub visit_installed_files {
    my ($self, $file) = @_;

    my $architecture = $self->processable->fields->value('Architecture');

    if ($file->name =~ m{^(?:usr/)?lib/([^/]+)/$}) {
        my $subdir = $1;
        if ($self->TRIPLETS->recognizes($subdir)) {

            $self->hint('triplet-dir-and-architecture-mismatch',
                $file->name, 'is for',$self->TRIPLETS->value($subdir))
              unless ($architecture eq $self->TRIPLETS->value($subdir));
        }
    }

    $self->_set_arch_dep_files(1)
      if !$file->is_dir
      && $file->name !~ m{^usr/share/}
      && $file->file_info
      && $file->file_info !~ m/\bASCII text\b/;

    if ($file->dirname =~ m{^(?:usr)?/lib/([^/]+)/$}) {
        $self->_set_arch_dep_files(1)
          if $self->TRIPLETS->recognizes($1 // $EMPTY);
    }

    return;
}

sub breakdown_installed_files {
    my ($self) = @_;

    my $architecture = $self->processable->fields->value('Architecture');

    # check if package is empty
    my $is_dummy = $self->processable->is_pkg_class('any-meta');

    $self->hint('package-contains-no-arch-dependent-files')
      unless $is_dummy
      || $self->arch_dep_files
      || $architecture eq 'all'
      || $self->processable->type eq 'udeb';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

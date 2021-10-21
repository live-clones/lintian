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

package Lintian::Check::Files::Architecture;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has TRIPLETS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $DEB_HOST_MULTIARCH
          = $self->profile->architectures->deb_host_multiarch;
        my %triplets = map { $DEB_HOST_MULTIARCH->{$_} => $_ }
          keys %{$DEB_HOST_MULTIARCH};

        return \%triplets;
    });

has depends_on_architecture => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $item) = @_;

    # for directories
    if ($item->name =~ m{^(?:usr/)?lib/([^/]+)/$}) {

        my $potential_triplet = $1;

        if (exists $self->TRIPLETS->{$potential_triplet}) {

            my $from_triplet = $self->TRIPLETS->{$potential_triplet};

            $self->hint('triplet-dir-and-architecture-mismatch',
                $item->name, 'is for', $from_triplet)
              unless $from_triplet eq
              $self->processable->fields->value('Architecture');
        }
    }

    # for files
    if ($item->dirname =~ m{^(?:usr)?/lib/([^/]+)/$}) {

        my $potential_triplet = $1;

        $self->depends_on_architecture(1)
          if exists $self->TRIPLETS->{$potential_triplet};
    }

    $self->depends_on_architecture(1)
      if $item->is_file
      && $item->size > 0
      && $item->file_info !~ m/^very short file/
      && $item->file_info !~ m/\bASCII text\b/
      && $item->name !~ m{^usr/share/};

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint('package-contains-no-arch-dependent-files')
      if !$self->depends_on_architecture
      && $self->processable->fields->value('Architecture') ne 'all'
      && $self->processable->type ne 'udeb'
      && !$self->processable->is_transitional
      && !$self->processable->is_meta_package;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

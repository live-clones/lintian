# files/multi-arch -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::MultiArch;

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

my %PATH_DIRECTORIES = map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin/ usr/games/ );

has has_public_executable => (is => 'rw', default => 0);
has has_public_shared_library => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $file) = @_;

    my $architecture = $self->processable->fields->value('Architecture');
    my $multiarch = $self->processable->fields->value('Multi-Arch') || 'no';

    my $DEB_HOST_MULTIARCH= $self->profile->architectures->deb_host_multiarch;
    my $multiarch_dir = $DEB_HOST_MULTIARCH->{$architecture};

    if (   !$file->is_dir
        && defined $multiarch_dir
        && $multiarch eq 'foreign'
        && $file->name =~ m{^usr/lib/\Q$multiarch_dir\E/(.*)$}) {

        my $tail = $1;

        $self->hint('multiarch-foreign-cmake-file', $file->name)
          if $tail =~ m{^cmake/.+\.cmake$};

        $self->hint('multiarch-foreign-pkgconfig', $file->name)
          if $tail =~ m{^pkgconfig/[^/]+\.pc$};

        $self->hint('multiarch-foreign-static-library', $file->name)
          if $tail =~ m{^lib[^/]+\.a$};
    }

    if (exists($PATH_DIRECTORIES{$file->dirname})) {
        $self->has_public_executable(1);
    }

    if ($file->name =~ m{^(?:usr/)?lib/(?:([^/]+)/)?lib[^/]*\.so$}) {
        $self->has_public_shared_library(1)
          if (!defined($1) || exists $self->TRIPLETS->{$1});
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $architecture = $self->processable->fields->value('Architecture');
    my $multiarch = $self->processable->fields->value('Multi-Arch') || 'no';

    $self->hint('multiarch-foreign-shared-library')
      if $architecture ne 'all'
      and $multiarch eq 'foreign'
      and $self->has_public_shared_library
      and not $self->has_public_executable;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

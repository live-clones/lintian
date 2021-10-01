# binaries/location -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2012 Kees Cook
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Binaries::Location;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

const my %PATH_DIRECTORIES => map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin/ usr/games/ );

has DEB_HOST_MULTIARCH => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->architectures->deb_host_multiarch;
    });

has gnu_triplet_pattern => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $gnu_triplet_pattern = $EMPTY;

        my $architecture = $self->processable->fields->value('Architecture');
        my $madir = $self->DEB_HOST_MULTIARCH->{$architecture};

        if (length $madir) {
            $gnu_triplet_pattern = quotemeta $madir;
            $gnu_triplet_pattern =~ s{^i386}{i[3-6]86};
        }

        return $gnu_triplet_pattern;
    });

has ruby_triplet_pattern => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $ruby_triplet_pattern = $self->gnu_triplet_pattern;
        $ruby_triplet_pattern =~ s{linux\\-gnu$}{linux};
        $ruby_triplet_pattern =~ s{linux\\-gnu}{linux\\-};

        return $ruby_triplet_pattern;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x
      || $item->file_info =~ / \b current [ ] ar [ ] archive \b /x;

    $self->hint('binary-in-etc', $item)
      if $item->name =~ m{^etc/};

    $self->hint('arch-dependent-file-in-usr-share', $item)
      if $item->name =~ m{^usr/share/};

    my $fields = $self->processable->fields;

    my $architecture = $fields->value('Architecture');
    my $multiarch = $fields->value('Multi-Arch') || 'no';

    my $gnu_triplet_pattern = $self->gnu_triplet_pattern;
    my $ruby_triplet_pattern = $self->ruby_triplet_pattern;

    $self->hint('arch-dependent-file-not-in-arch-specific-directory',$item)
      if $multiarch eq 'same'
      && length $gnu_triplet_pattern
      && $item->name !~ m{\b$gnu_triplet_pattern(?:\b|_)}
      && length $ruby_triplet_pattern
      && $item->name !~ m{/$ruby_triplet_pattern/}
      && $item->name !~ m{/java-\d+-openjdk-\Q$architecture\E/}
      && $item->name !~ m{/[.]build-id/};

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    $self->hint('development-package-ships-elf-binary-in-path', $item)
      if exists $PATH_DIRECTORIES{$item->dirname}
      && $fields->value('Section') =~ m{ (?:^|/) libdevel $}x
      && $fields->value('Multi-Arch') ne 'foreign';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

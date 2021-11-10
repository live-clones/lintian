# binaries/rpath -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::Rpath;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Spec;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SLASH => q{/};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

has DEB_HOST_MULTIARCH => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->architectures->deb_host_multiarch;
    });

has multiarch_component => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $architecture = $self->processable->fields->value('Architecture');
        my $multiarch_component = $self->DEB_HOST_MULTIARCH->{$architecture};

        return $multiarch_component;
    });

has private_folders => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @lib_folders = qw{lib};

        push(@lib_folders,
            map { $_ . $SLASH . $self->multiarch_component } @lib_folders)
          if length $self->multiarch_component;

        my @usrlib_folders = qw{usr/lib};

        push(@usrlib_folders,
            map { $_ . $SLASH . $self->multiarch_component } @usrlib_folders)
          if length $self->multiarch_component;

        my @game_folders = map { "$_/games" } @usrlib_folders;

        my @private_folders
          = map { $_ . $SLASH . $self->processable->source_name }
          (@lib_folders, @usrlib_folders, @game_folders);

        return \@private_folders;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    for my $section (qw{RPATH RUNPATH}) {

        my @rpaths = keys %{$item->elf->{$section} // {}};

        my @no_origin = grep { !m{^ \$ \{? ORIGIN \}? }x } @rpaths;

        my @canonical = map { File::Spec->canonpath($_) } @no_origin;

        my @custom;
        for my $folder (@canonical) {

            # for shipped folders, would have to disallow system locations
            next
              if any { $folder =~ m{^ / \Q$_\E }x } @{$self->private_folders};

            # GHC in Debian uses a scheme for RPATH (#914873)
            next
              if $folder =~ m{^ /usr/lib/ghc (?: / | $ ) }x;

            push(@custom, $folder);
        }

        my @absolute = grep { m{^ / }x } @custom;

        $self->hint('custom-library-search-path', $section, $_,
            $LEFT_SQUARE_BRACKET . $item->name. $RIGHT_SQUARE_BRACKET)
          for @absolute;

        my @relative = grep { m{^ [^/] }x } @custom;

        $self->hint('relative-library-search-path',
            $section, $_,
            $LEFT_SQUARE_BRACKET . $item->name. $RIGHT_SQUARE_BRACKET)
          for @relative;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

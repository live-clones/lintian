# debian/copyright/dep5/components -- lintian check script -*- perl -*-

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

package Lintian::Check::Debian::Copyright::Dep5::Components;

use v5.20;
use warnings;
use utf8;

use List::Compare;
use Syntax::Keyword::Try;

use Lintian::Deb822::File;
use Lintian::Pointer::Item;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless defined $debian_dir;

    my @installables = $self->processable->debian_control->installables;
    my @additional = map { $_ . '.copyright' } @installables;

    my @candidates = ('copyright', @additional);
    my @files = grep { defined $_ && !$_->is_symlink }
      map { $debian_dir->child($_) } @candidates;

    # another check complains about legacy encoding, if needed
    my @valid_utf8 = grep { $_->is_valid_utf8 } @files;

    $self->check_dep5_copyright($_) for @valid_utf8;

    return;
}

sub check_dep5_copyright {
    my ($self, $copyright_file) = @_;

    my $deb822 = Lintian::Deb822::File->new;

    my @sections;
    try {
        @sections = $deb822->read_file($copyright_file->unpacked_path);

    } catch {
        # may not be in DEP 5 format
        return;
    }

    return
      unless @sections;

    my ($header, @followers) = @sections;

    my @initial_path_components;

    for my $section (@followers) {

        my @subdirs = $section->trimmed_list('Files');
        s{ / .* $}{}x for @subdirs;

        my @definite = grep { !/[*?]/ } @subdirs;

        push(@initial_path_components, grep { length } @definite);
    }

    my @extra_source_components
      = grep { length } values %{$self->processable->components};
    my $component_lc = List::Compare->new(\@extra_source_components,
        \@initial_path_components);

    my @missing_components = $component_lc->get_Lonly;

    my $pointer = Lintian::Pointer::Item->new;
    $pointer->item($copyright_file);

    $self->pointed_hint('add-component-copyright', $pointer, $_)
      for @missing_components;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

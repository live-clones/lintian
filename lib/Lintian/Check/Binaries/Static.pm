# binaries/static -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::Static;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has built_with_golang => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $built_with_golang = $self->processable->name =~ m/^golang-/;

        my $source = $self->group->source;

        $built_with_golang
          = $source->relation('Build-Depends-All')
          ->satisfies('golang-go | golang-any')
          if defined $source;

        return $built_with_golang;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      if $self->processable->type eq 'udeb';

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    return
      unless $item->file_info =~ m{ executable | shared [ ] object }x;

    my $is_shared = $item->file_info =~ m/(shared object|pie executable)/;

    # Some exceptions: files in /boot, /usr/lib/debug/*,
    # named *-static or *.static, or *-static as
    # package-name.
    # Binaries built by the Go compiler are statically
    # linked by default.
    # klibc binaries appear to be static.
    # Location of debugging symbols.
    # ldconfig must be static.
    $self->hint('statically-linked-binary', $item)
      if !$is_shared
      && !exists $item->elf->{NEEDED}
      && $item->name !~ m{^boot/}
      && $item->name !~ /[\.-]static$/
      && $self->processable->name !~ /-static$/
      && !$self->built_with_golang
      && (!exists $item->elf->{INTERP}
        || $item->elf->{INTERP} !~ m{/lib/klibc-\S+\.so})
      && $item->name !~ m{^usr/lib/debug/}
      && $item->name ne 'sbin/ldconfig';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

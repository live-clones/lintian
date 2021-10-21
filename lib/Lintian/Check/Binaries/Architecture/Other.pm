# binaries/architecture/other -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::Architecture::Other;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Guile object files do not objdump/strip correctly, so exclude them
# from a number of tests. (#918444)
const my $GUILE_PATH_REGEX => qr{^usr/lib(?:/[^/]+)+/guile/[^/]+/.+\.go$};

has ARCH_REGEX => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/arch-regex', qr/\s*\~\~/,
            sub { return qr/$_[1]/ });
    });

has ARCH_64BIT_EQUIVS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/arch-64bit-equivs',
            qr/\s*\=\>\s*/);
    });

sub from_other_architecture {
    my ($self, $item) = @_;

    my $architecture = $self->processable->fields->value('Architecture');

    return 0
      if $architecture eq 'all';

    # If it matches the architecture regex, it is good
    return 0
      if $self->ARCH_REGEX->recognizes($architecture)
      && $item->file_info =~ $self->ARCH_REGEX->value($architecture);

    # Special case - "old" multi-arch dirs
    if (   $item->name =~ m{(?:^|/)lib(x?\d\d)/}
        || $item->name =~ m{^emul/ia(\d\d)}) {

        my $bus_width = $1;

        return 0
          if $self->ARCH_REGEX->value($bus_width)
          && $item->file_info =~ $self->ARCH_REGEX->value($bus_width);
    }

    # Detached debug symbols could be for a biarch library.
    return 0
      if $item->name =~ m{^usr/lib/debug/\.build-id/};

    # Guile binaries do not objdump/strip (etc.) correctly.
    return 0
      if $item->name =~ $GUILE_PATH_REGEX;

    # Allow amd64 kernel modules to be installed on i386.
    if (   $item->name =~ m{^lib/modules/}
        && $self->ARCH_64BIT_EQUIVS->recognizes($architecture)) {

        my $equivalent_64 = $self->ARCH_64BIT_EQUIVS->value($architecture);

        return 0
          if $item->file_info =~ $self->ARCH_REGEX->value($equivalent_64);
    }

    # Ignore i386 binaries in amd64 packages for right now.
    return 0
      if $architecture eq 'amd64'
      && $item->file_info =~ $self->ARCH_REGEX->value('i386');

    return 1;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    $self->hint('binary-from-other-architecture', $item)
      if $self->from_other_architecture($item);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

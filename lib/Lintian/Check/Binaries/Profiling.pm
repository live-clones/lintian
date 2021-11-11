# binaries/profiling -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::Profiling;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $item) = @_;

    my $architecture = $self->processable->fields->value('Architecture');

    my $is_profiled = 0;

    for my $symbol (@{$item->elf->{SYMBOLS} // [] }) {

        # According to the binutils documentation[1], the profiling symbol
        # can be named "mcount", "_mcount" or even "__mcount".
        # [1] http://sourceware.org/binutils/docs/gprof/Implementation.html
        $is_profiled = 1
          if $symbol->version =~ /^GLIBC_.*/
          && $symbol->name =~ m{\A _?+ _?+ (gnu_)?+mcount(_nc)?+ \Z}xsm
          && ($symbol->section eq 'UND' || $symbol->section eq '.text');

        # This code was used to detect profiled code in Wheezy and earlier
        $is_profiled = 1
          if $symbol->section eq '.text'
          && $symbol->version eq 'Base'
          && $symbol->name eq '__gmon_start__'
          && $architecture ne 'hppa';
    }

    $self->hint('binary-compiled-with-profiling-enabled', $item->name)
      if $is_profiled;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

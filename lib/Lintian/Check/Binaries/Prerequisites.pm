# binaries/prerequisites -- lintian check script -*- perl -*-

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

package Lintian::Check::Binaries::Prerequisites;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

# Guile object files do not objdump/strip correctly, so exclude them
# from a number of tests. (#918444)
const my $GUILE_PATH_REGEX => qr{^usr/lib(?:/[^/]+)+/guile/[^/]+/.+\.go$};

has built_with_octave => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $built_with_octave = $self->processable->name =~ m/^octave-/;

        my $source = $self->group->source;

        $built_with_octave
          = $source->relation('Build-Depends')->satisfies('dh-octave')
          if defined $source;

        return $built_with_octave;
    });

has files_by_library => (is => 'rw', default => sub  { {} });

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

    for my $library (@{$item->elf->{NEEDED} // [] }) {

        $self->files_by_library->{$library} //= [];
        push(@{$self->files_by_library->{$library}}, $item->name);
    }

    # Some exceptions: kernel modules, syslinux modules, detached
    # debugging information and the dynamic loader (which itself
    # has no dependencies).
    $self->hint('shared-library-lacks-prerequisites', $item)
      if $is_shared
      && !@{$item->elf->{NEEDED} // []}
      && $item->name !~ m{^boot/modules/}
      && $item->name !~ m{^lib/modules/}
      && $item->name !~ m{^usr/lib/debug/}
      && $item->name !~ m{\.(?:[ce]32|e64)$}
      && $item->name !~ m{^usr/lib/jvm/.*\.debuginfo$}
      && $item->name !~ $GUILE_PATH_REGEX
      && $item->name !~ m{
                          ^lib(?:|32|x32|64)/
                           (?:[-\w/]+/)?
                           ld-[\d.]+\.so$
                        }xsm;

    my $depends = $self->processable->relation('strong');

    $self->hint('undeclared-elf-prerequisites', $item->name,
            $LEFT_PARENTHESIS
          . join($SPACE, sort +uniq @{$item->elf->{NEEDED} // []})
          . $RIGHT_PARENTHESIS)
      if @{$item->elf->{NEEDED} // [] }
      && $depends->is_empty;

    # If there is no libc dependency, then it is most likely a
    # bug.  The major exception is that some C++ libraries,
    # but these tend to link against libstdc++ instead.  (see
    # #719806)
    my $linked_with_libc
      = any { m{^ libc[.]so[.] }x } @{$item->elf->{NEEDED} // []};

    $self->hint('library-not-linked-against-libc', $item)
      if !$linked_with_libc
      && $is_shared
      && @{$item->elf->{NEEDED} // [] }
      && (none { /^libc[.]so[.]/ } @{$item->elf->{NEEDED} // [] })
      && $item->name !~ m{/libc\b}
      && (!$self->built_with_octave
        || $item->name !~ m/\.(?:oct|mex)$/);

    $self->hint('program-not-linked-against-libc', $item)
      if !$linked_with_libc
      && !$is_shared
      && @{$item->elf->{NEEDED} // [] }
      && (
        none { /^libstdc[+][+][.]so[.]/ }
        @{$item->elf->{NEEDED} // [] })&& !$self->built_with_octave;

    return;
}

sub installable {
    my ($self) = @_;

    my $depends = $self->processable->relation('strong');
    return
      if $depends->is_empty;

    my %libc_files;
    for my $library (keys %{$self->files_by_library}) {

        # Match libcXX or libcXX-*, but not libc3p0.
        next
          unless $library =~ m{^ libc [.] so [.] (\d+ .*) $}x;

        my $package = "libc$1";

        $libc_files{$package} //= [];
        push(@{$libc_files{$package}}, @{$self->files_by_library->{$library}});
    }

    for my $package (keys %libc_files) {

        next
          if $depends->matches(qr/^\Q$package\E\b/);

        my @sorted = sort +uniq @{$libc_files{$package}};

        my $context = 'needed by ' . $sorted[0];
        $context .= ' and ' . (scalar @sorted - 1) . ' others'
          if @sorted > 1;

        $self->hint('missing-dependency-on-libc', $context)
          unless $self->processable->name =~ m{^ libc [\d.]+ (?:-|\z) }x;
    }

    my %libcxx_files;
    for my $library (keys %{$self->files_by_library}) {

        # Match libstdc++XX or libcstdc++XX-*
        next
          unless $library =~ m{^ libstdc[+][+] [.] so [.] (\d+) $}xsm;

        my $package = "libstdc++$1";

        $libcxx_files{$package} //= [];
        push(@{$libcxx_files{$package}},
            @{$self->files_by_library->{$library}});
    }

    for my $package (keys %libcxx_files) {

        next
          if $depends->matches(qr/^\Q$package\E\b/);

        my @sorted = sort +uniq @{$libcxx_files{$package}};

        my $context = 'needed by ' . $sorted[0];
        $context .= ' and ' . (scalar @sorted - 1) . ' others'
          if @sorted > 1;

        $self->hint('missing-dependency-on-libstdc++', $context);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

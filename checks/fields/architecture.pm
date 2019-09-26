# fields/architecture -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::fields::architecture;

use strict;
use warnings;
use autodie;

use Lintian::Architecture qw(:all);
use Lintian::Tags qw(tag);

sub binary {
    my ($pkg, undef, $info, undef, undef) = @_;

    my $unsplit = $info->unfolded_field('architecture');

    return
      unless defined $unsplit;

    my @list = split(m/ /o, $unsplit);

    return
      unless @list;

    for my $architecture (@list) {
        tag 'arch-wildcard-in-binary-package', $architecture
          if is_arch_wildcard($architecture);
    }

    tag 'too-many-architectures'
      if @list > 1;

    my $architecture = $list[0];

    return
      if $architecture eq 'all';

    tag 'aspell-package-not-arch-all'
      if $pkg =~ /^aspell-[a-z]{2}(?:-.*)?$/;

    tag 'documentation-package-not-architecture-independent'
      if $pkg =~ /-docs?$/;

    if ($pkg =~ /^r-(?:cran|bioc|other)-/) {

        for my $file ($info->sorted_index) {

            next
              if $file->is_dir;

            next
              unless $file =~ m,^usr/lib/R/.*/DESCRIPTION,;

            tag 'r-package-not-arch-all'
              if $file->file_contents =~ m/NeedsCompilation: no/m;

            last;
        }
    }

    return;
}

sub always {
    my (undef, $type, $info, undef, undef) = @_;

    my $architecture = $info->unfolded_field('architecture');

    unless (defined $architecture) {
        tag 'no-architecture-field';
        return;
    }

    my @list = split(m/ /o, $architecture);

    for my $arch (@list) {

        tag 'unknown-architecture', $arch
          unless is_arch_or_wildcard($arch);
    }

    if (@list > 1) {    # Check for magic architecture combinations.

        my %archmap;
        my $magic = 0;

        $archmap{$_}++ for (@list);

        $magic++
          if $type ne 'source' && $archmap{'all'};

        if ($archmap{'any'}) {

            delete $archmap{'any'};

            # Allow 'all' to be present in source packages as well
            # (#626775)
            delete $archmap{'all'}
              if $type eq 'source';

            $magic++
              if %archmap;
        }

        tag 'magic-arch-in-arch-list'
          if $magic;
    }

    # Used for later tests.
    my $arch_indep = 0;
    $arch_indep = 1
      if @list == 1 && $list[0] eq 'all';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

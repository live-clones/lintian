# fields/multi-arch -- lintian check script (rewrite) -*- perl -*-
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

package Lintian::fields::multi_arch;

use strict;
use warnings;
use autodie;

use List::MoreUtils qw(uniq);

use Lintian::Tags qw(tag);
use Lintian::Util qw(safe_qx);

use constant EMPTY => q{};
use constant SPACE => q{ };

sub source {
    my ($pkg, undef, $info, undef, undef) = @_;

    for my $bin ($info->binaries) {

        next
          unless $info->binary_field($bin, 'multi-arch', EMPTY) eq 'same';

        my $wildcard = $info->binary_field($bin, 'architecture');
        my @arches   = split(
            SPACE,
            safe_qx(
                'dpkg-architecture', '--match-wildcard',
                $wildcard,           '--list-known'
            ));

        # include original wildcard
        push(@arches, $wildcard);

        foreach my $arch (uniq @arches) {

            my $specific = "debian/$bin.lintian-overrides.$arch";

            tag 'multi-arch-same-package-has-arch-specific-overrides',
              $specific
              if $info->index_resolved_path($specific);
        }
    }

    return;
}

sub binary {
    my ($pkg, undef, $info, undef, undef) = @_;

    if ($pkg =~ /^x?fonts-/) {
        tag 'font-package-not-multi-arch-foreign'
          unless $info->field('multi-arch', 'no') =~m/^(?:foreign|allowed)$/o;
    }

    my $multi = $info->unfolded_field('multi-arch');

    return
      unless defined $multi;

    my $architecture = $info->unfolded_field('architecture');
    if (defined $architecture) {

        tag 'illegal-multi-arch-value', $architecture, $multi
          if $architecture eq 'all' && $multi eq 'same';
    }

    return;
}

sub always {
    my ($pkg, undef, $info, undef, undef) = @_;

    my $multi = $info->unfolded_field('multi-arch');

    return
      unless defined $multi;

    tag 'unknown-multi-arch-value', $pkg, $multi
      unless $multi =~ m/^(?:no|foreign|allowed|same)$/o;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

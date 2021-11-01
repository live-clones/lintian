# debian/control/field/description/duplicate -- lintian check script -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Check::Debian::Control::Field::Description::Duplicate;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;

    my %installables_by_synopsis;
    my %installables_by_exended;

    for my $installable ($control->installables) {

        my $description
          = $control->installable_fields($installable)
          ->untrimmed_value('Description');

        next
          unless length $description;

        next
          if $control->installable_package_type($installable) eq 'udeb';

        my ($synopsis, $extended) = split(/\n/, $description, 2);

        $synopsis //= $EMPTY;
        $extended //= $EMPTY;

        # trim both ends
        $synopsis =~ s/^\s+|\s+$//g;
        $extended =~ s/^\s+|\s+$//g;

        if (length $synopsis) {
            $installables_by_synopsis{$synopsis} //= [];
            push(@{$installables_by_synopsis{$synopsis}}, $installable);
        }

        if (length $extended) {
            $installables_by_exended{$extended} //= [];
            push(@{$installables_by_exended{$extended}}, $installable);
        }
    }

    # check for duplicate short description
    for my $synopsis (keys %installables_by_synopsis) {

        # Assume that substvars are correctly handled
        next
          if $synopsis =~ m/\$\{.+\}/;

        $self->hint('duplicate-short-description',
            (sort @{$installables_by_synopsis{$synopsis}}))
          if scalar @{$installables_by_synopsis{$synopsis}} > 1;
    }

    # check for duplicate long description
    for my $extended (keys %installables_by_exended) {

        # Assume that substvars are correctly handled
        next
          if $extended =~ m/\$\{.+\}/;

        $self->hint('duplicate-long-description',
            (sort @{$installables_by_exended{$extended}}))
          if scalar @{$installables_by_exended{$extended}} > 1;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

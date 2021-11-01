# substvars/libc -- lintian check script -*- perl -*-
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

package Lintian::Check::Substvars::Libc;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

# The list of libc packages, used for checking for a hard-coded dependency
# rather than using ${shlibs:Depends}.
my @LIBCS = qw(libc6 libc6.1 libc0.1 libc0.3);
my $LIBC_RELATION = Lintian::Relation->new->load(join(' | ', @LIBCS));

sub source {
    my ($self) = @_;

    my $control = $self->processable->debian_control;

    my @prerequisite_fields = qw(Pre-Depends Depends Recommends Suggests);

    for my $installable ($control->installables) {
        my $installable_fields = $control->installable_fields($installable);

        for my $field (@prerequisite_fields) {

            next
              unless $control->installable_fields($installable)
              ->declares($field);

            my $relation
              = $self->processable->binary_relation($installable,$field);

            $self->hint(
                'package-depends-on-hardcoded-libc',
                $field,
                $relation->to_string,
                "(in section for $installable)",
                $LEFT_SQUARE_BRACKET
                  . 'debian/control:'
                  . $installable_fields->position($field)
                  . $RIGHT_SQUARE_BRACKET
              )
              if $relation->satisfies($LIBC_RELATION)
              && $self->processable->name !~ /^e?glibc$/;
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

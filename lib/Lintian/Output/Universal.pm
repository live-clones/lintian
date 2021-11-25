# Copyright © 2019 Felix Lechner
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

package Lintian::Output::Universal;

use v5.20;
use warnings;
use utf8;

use Carp;
use Const::Fast;
use List::SomeUtils qw(all);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

const my $SPACE => q{ };
const my $COLON => q{:};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

=head1 NAME

Lintian::Output::Universal -- Facilities for printing universal hints

=head1 SYNOPSIS

 use Lintian::Output::Universal;

=head1 DESCRIPTION

A class for printing hints using the 'universal' format.

=head1 INSTANCE METHODS

=over 4

=item issue_hints

Print all hints passed in array. A separate arguments with processables
is necessary to report in case no hints were found.

=cut

sub issue_hints {
    my ($self, $groups) = @_;

    for my $group (@{$groups // []}) {

        my @by_group;
        for my $processable ($group->get_processables) {

            for my $hint (@{$processable->hints}) {

                my $tag = $hint->tag;

                my $line
                  = $processable->name
                  . $SPACE
                  . $LEFT_PARENTHESIS
                  . $processable->type
                  . $RIGHT_PARENTHESIS
                  . $COLON
                  . $SPACE
                  . $tag->name;

                $line .= $SPACE . $hint->context
                  if length $hint->context;

                push(@by_group, $line);
            }
        }

        my @sorted
          = reverse sort { order($a) cmp order($b) } @by_group;

        say encode_utf8($_) for @sorted;
    }

    return;
}

=item order

=cut

sub order {
    my ($line) = @_;

    return package_type($line) . $line;
}

=item package_type

=cut

sub package_type {
    my ($line) = @_;

    my (undef, $type, undef, undef) = parse_line($line);
    return $type;
}

=item parse_line

=cut

sub parse_line {
    my ($line) = @_;

    my ($package, $type, $name, $details)
      = $line =~ qr/^(\S+)\s+\(([^)]+)\):\s+(\S+)(?:\s+(.*))?$/;

    croak encode_utf8("Cannot parse line $line")
      unless all { length } ($package, $type, $name);

    return ($package, $type, $name, $details);
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

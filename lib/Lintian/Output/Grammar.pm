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

package Lintian::Output::Grammar;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $COMMA => q{,};

=head1 NAME

Lintian::Output::Grammar - sentence helpers

=head1 SYNOPSIS

    use Lintian::Output::Grammar;

=head1 DESCRIPTION

Helps with human readable output.

=head1 INSTANCE METHODS

=over 4

=item oxford_enumeration

=cut

sub oxford_enumeration {
    my ($self, $conjunctive, @alternatives) = @_;

    return $EMPTY
      unless @alternatives;

    # remove and save last element
    my $final = pop @alternatives;

    my $maybe_comma = (@alternatives > 1 ? $COMMA : $EMPTY);

    my $text = $EMPTY;
    $text = join($COMMA . $SPACE, @alternatives) . "$maybe_comma $conjunctive "
      if @alternatives;

    $text .= $final;

    return $text;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

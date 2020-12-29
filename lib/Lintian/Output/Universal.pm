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
const my $LPARENS => q{(};
const my $RPARENS => q{)};

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

    my @processables = map { $_->get_processables } @{$groups // []};

    my @pending;
    for my $processable (@processables) {

        # get hints
        my @hints = @{$processable->hints};

        # associate hints with processable
        $_->processable($processable) for @hints;

        # remove circular references
        $processable->hints([]);

        push(@pending, @hints);
    }

    my %hintlist;

    for my $hint (@pending) {
        $hintlist{$hint->processable} //= [];
        push(@{$hintlist{$hint->processable}}, $hint);
    }

    my @lines;

    for my $processable (@processables) {

        my $object = 'package';
        $object = 'file'
          if $processable->type eq 'changes';

        my @subset = @{$hintlist{$processable} // []};

        for my $hint (@subset) {

            my $details = $hint->context;

            my $line
              = $processable->name
              . $SPACE
              . $LPARENS
              . $processable->type
              . $RPARENS
              . $COLON
              . $SPACE
              . $hint->tag->name;
            $line .= $SPACE . $details
              if length $details;

            push(@lines, $line);
        }
    }

    my @sorted
      = reverse sort { order($a) cmp order($b) } @lines;

    say encode_utf8($_) for @sorted;

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

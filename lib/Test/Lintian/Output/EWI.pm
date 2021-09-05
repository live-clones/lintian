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
# MA 02110-1301, USA

package Test::Lintian::Output::EWI;

=head1 NAME

Test::Lintian::Output::EWI -- routines to process EWI hints

=head1 SYNOPSIS

  use Path::Tiny;
  use Test::Lintian::Output::EWI qw(to_universal);

  my $ewi = path("path to an EWI hint file")->slurp_utf8;
  my $universal = to_universal($ewi);

=head1 DESCRIPTION

Helper routines to deal with C<EWI> hints and hint files

=cut

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      to_universal
    );
}

use Carp;
use Const::Fast;
use List::Util qw(all);
use Unicode::UTF8 qw(encode_utf8);

use Test::Lintian::Output::Universal qw(universal_string order);

const my $EMPTY   => q{};
const my $NEWLINE => qq{\n};

=head1 FUNCTIONS

=over 4

=item to_universal(STRING)

Converts the C<EWI> hint data contained in STRING to universal hints.
They are likewise delivered in a multi-line string.

=cut

sub to_universal {
    my ($ewi) = @_;

    my @unsorted;

    my @lines = split($NEWLINE, $ewi);
    chomp @lines;

    foreach my $line (@lines) {

        # no hint in this line
        next if $line =~ /^N: /;

        # look for "EWI: package[ type]: name details"
        my ($code, $package, $type, $name, $details)
          = $line=~ /^(.): (\S+)(?: (changes|source|udeb))?: (\S+)(?: (.*))?$/;

        # for binary packages, the type field is empty
        $type //= 'binary';

        croak encode_utf8("Cannot parse line $line")
          unless all { length } ($code, $package, $type, $name);

        my $converted = universal_string($package, $type, $name, $details);
        push(@unsorted, $converted);
    }

    my @sorted = reverse sort { order($a) cmp order($b) } @unsorted;

    my $universal = $EMPTY;
    $universal .= $_ . $NEWLINE for @sorted;

    return $universal;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

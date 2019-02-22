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

package Test::Lintian::Output::LetterQualifier;

=head1 NAME

Test::Lintian::Output::LetterQualifier -- routines to process letter-qualifier tags

=head1 SYNOPSIS

  use Path::Tiny;
  use Test::Lintian::Output::LetterQualifier qw(to_universal);

  my $ewi = path("path to an LetterQualifier tag file")->slurp_utf8;
  my $universal = to_universal($ewi);

=head1 DESCRIPTION

Helper routines to deal with letter-qualifier tags and tag files

=cut

use strict;
use warnings;
use autodie;
use v5.10;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      to_universal
    );
}

use Test::Lintian::Output::EWI;

use constant NEWLINE => qq{\n};

=head1 FUNCTIONS

=over 4

=item to_universal(STRING)

Converts the letter-qualifier tag data contained in STRING to universal tags.
They are likewise delivered in a multi-line string.

=cut

sub to_universal {
    my ($letterqualifier) = @_;

    my @lines = split(NEWLINE, $letterqualifier);
    chomp @lines;

    s/^(.)\[..\](.*)$/$1$2/ for @lines;

    my $ewi;
    $ewi .= $_ . NEWLINE for @lines;

    return Test::Lintian::Output::EWI::to_universal($ewi);
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

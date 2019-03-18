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

package Test::Lintian::Output::XML;

=head1 NAME

Test::Lintian::Output::XML -- routines to process C<XML> tags

=head1 SYNOPSIS

  use Path::Tiny;
  use Test::Lintian::Output::XML qw(to_universal);

  my $xml = path("path to an XML tag file")->slurp_utf8;
  my $universal = to_universal($xml);

=head1 DESCRIPTION

Helper routines to deal with C<XML> tags and tag files

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

use Carp;
use List::Util qw(all);
use XML::LibXML;

use Test::Lintian::Output::Universal qw(universal_string order);

use constant EMPTY   => q{};
use constant NEWLINE => qq{\n};

=head1 FUNCTIONS

=over 4

=item to_universal(STRING)

Converts the C<XML> tag data contained in STRING to universal tags.
They are likewise delivered in a multi-line string.

=cut

sub to_universal {
    my ($xml) = @_;

    my @unsorted;

    my $string = '<lintian>' . $xml . '</lintian>';
    my $dom = XML::LibXML->load_xml(string => $string);

    my @packagenodes = $dom->findnodes('/lintian/package');
    croak 'No packages in XML'
      unless scalar @packagenodes;

    foreach my $packagenode (@packagenodes) {

        my $package = $packagenode->getAttribute('name');
        my $type = $packagenode->getAttribute('type');

        croak 'Cannot parse package node in XML'
          unless all { length } ($package, $type);

        my @tagsnodes = $packagenode->findnodes('./tag');
        foreach my $tagnode (@tagsnodes) {

            my $severity = $tagnode->getAttribute('severity');
            my $certainty = $tagnode->getAttribute('certainty');
            my $name = $tagnode->getAttribute('name');
            my $details = $tagnode->to_literal;

            croak 'Cannot parse tag node in XML'
              unless all { length } ($severity, $certainty, $name);

            my $converted = universal_string($package, $type, $name, $details);
            push(@unsorted, $converted);
        }
    }

    my @sorted = reverse sort { order($a) cmp order($b) } @unsorted;

    my $universal = EMPTY;
    $universal .= $_ . NEWLINE for @sorted;

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

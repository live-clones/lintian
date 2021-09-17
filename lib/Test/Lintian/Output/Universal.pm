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

package Test::Lintian::Output::Universal;

=head1 NAME

Test::Lintian::Output::Universal -- routines to process universal hints

=head1 SYNOPSIS

  use Test::Lintian::Output::Universal qw(get_tagnames);

  my $filepath = "path to a universal hint file";
  my @tags = get_tagnames($filepath);

=head1 DESCRIPTION

Helper routines to deal with universal hints and hint files. This is an
abstract format that has the minimum information found in all Lintian
output formats.

=cut

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      get_tagnames
      order
      package_name
      package_type
      tag_name
      parse_line
      universal_string
    );
}

use Carp;
use Const::Fast;
use List::SomeUtils qw(uniq);
use List::Util qw(all);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

const my $SPACE => q{ };
const my $COLON => q{:};
const my $LPARENS => q{(};
const my $RPARENS => q{)};

=head1 FUNCTIONS

=over 4

=item get_tagnames(PATH)

Gets all the tag names mentioned in universal hint file located
at PATH.

=cut

sub get_tagnames {
    my ($path) = @_;

    my @lines = path($path)->lines_utf8({ chomp => 1 });
    my @names = map { tag_name($_) } @lines;

    return uniq @names;
}

=item order

=cut

sub order {
    my ($line) = @_;

    return package_type($line) . $line;
}

=item package_name

=cut

sub package_name {
    my ($line) = @_;

    my ($package, undef, undef, undef) = parse_line($line);
    return $package;
}

=item package_type

=cut

sub package_type {
    my ($line) = @_;

    my (undef, $type, undef, undef) = parse_line($line);
    return $type;
}

=item tag_name

=cut

sub tag_name {
    my ($line) = @_;

    my (undef, undef, $name, undef) = parse_line($line);
    return $name;
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

=item universal_string

=cut

sub universal_string {
    my ($package, $type, $name, $details) = @_;

    croak encode_utf8('Need a package name')
      unless length $package;
    croak encode_utf8('Need a package type')
      unless length $type;
    croak encode_utf8('Need a tag name')
      unless length $name;

    my $line
      = $package. $SPACE. $LPARENS. $type. $RPARENS. $COLON. $SPACE. $name;
    $line .= $SPACE . $details
      if length $details;

    return $line;
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

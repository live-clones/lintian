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

use strict;
use warnings;
use v5.12;

use List::MoreUtils qw(all);

use Lintian::Output qw(:util);
use parent qw(Lintian::Output);

use Carp;

use constant SPACE => q{ };
use constant EMPTY => q{};
use constant COLON => q{:};
use constant LPARENS => q{(};
use constant RPARENS => q{)};
use constant NEWLINE => qq{\n};

sub print_tag {
    my ($self, $pkg_info, $tag_info, $details, $override) = @_;
    $self->issued_tag($tag_info->tag);

    my $odata = '';
    if ($override) {
        $odata = $override->tag;
        $odata .= ' ' . $self->_quote_print($override->extra)
          if $override->extra;
    }

    my $line
      = $pkg_info->{package}
      . SPACE
      . LPARENS
      . $pkg_info->{type}
      . RPARENS
      . COLON
      . SPACE
      . $tag_info->tag;
    $line .= SPACE . $details
      if length $details;

    push(@{$self->{lines}}, $line);

    return;
}

sub _message {
    my ($self, @args) = @_;
    return;
}

sub _warning {
    my ($self, @args) = @_;
    return;
}

sub print_first {
    my ($self, $pkg_info) = @_;
    $self->{lines} = [];
    return;
}

sub order {
    my ($line) = @_;

    return package_type($line) . $line;
}

sub package_type {
    my ($line) = @_;

    my (undef, $type, undef, undef) = parse_line($line);
    return $type;
}

sub parse_line {
    my ($line) = @_;

    my ($package, $type, $name, $details)
      = $line =~ qr/^(\S+)\s+\(([^)]+)\):\s+(\S+)(?:\s+(.*))?$/;

    croak "Cannot parse line $line"
      unless all { length } ($package, $type, $name);

    return ($package, $type, $name, $details);
}

sub print_last {
    my ($self) = @_;
    my @sorted
      = reverse sort { order($a) cmp order($b) } @{$self->{lines}};
    print { $self->stdout } $_ . NEWLINE for @sorted;
    return;
}

sub _delimiter {
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

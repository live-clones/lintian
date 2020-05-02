# fields/length -- lintian check script -*- perl -*-
#
# Copyright © 2019 Sylvestre Ledru
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::fields::length;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use List::MoreUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @ALLOWED_FIELDS
  = qw(build-ids description package-list installed-build-depends checksums-sha256);

sub always {
    my ($self) = @_;

    return
      if any { $self->type eq $_ } ('changes', 'buildinfo');

    my $maximum = 5_000;

    # all fields
    my @all = keys %{$self->processable->field};

    # longer than maximum
    my @long = grep { length $self->processable->field($_) > $maximum } @all;

    # filter allowed fields
    my $allowedlc = List::Compare->new(\@long, \@ALLOWED_FIELDS);
    my @too_long = $allowedlc->get_Lonly;

    for my $name (@too_long) {

        # title-case the field name
        (my $label = $name) =~ s/\b(\w)/\U$1/g;

        my $length = length $self->processable->field($name);

        $self->tag('field-too-long', $label, "($length chars > $maximum)");
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

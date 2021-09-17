# languages/python/dist-overrides -- lintian check script -*- perl -*-
#
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

package Lintian::Check::Languages::Python::DistOverrides;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

sub source {
    my ($self) = @_;

    my $override_file
      = $self->processable->patched->resolve_path('debian/py3dist-overrides');
    return
      unless defined $override_file;

    my $contents = $override_file->decoded_utf8;
    return
      unless length $contents;

    # strip comments
    $contents =~ s/^\s*\#.*$//mg;

    # strip empty lines
    $contents =~ s/^\s*$//mg;

    # trim leading spaces
    $contents =~ s/^\s*//mg;

    my @lines = split(/\n/, $contents);

    # get first component from each line
    my @identifiers
      = grep { defined } map { (split($SPACE, $_, 2))[0] } @lines;

    my %count;
    $count{$_}++ for @identifiers;

    my @duplicates = grep { $count{$_} > 1 } uniq @identifiers;

    $self->hint('duplicate-p3dist-override', $_) for @duplicates;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# Copyright © 2019 Felix Lechner <felix.lechner@lease-up.com>
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

package Lintian::Tag::Issuer;

use strict;
use warnings;
use v5.16;

use Lintian::Tags;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Tag::Issuer -- Facilities for objects issuing Lintian tags

=head1 SYNOPSIS

 use Moo;
use namespace::clean;

 with('Lintian::Tag::Issuer');

=head1 DESCRIPTION

A class for collecting Lintian tags as they are issued

=head1 INSTANCE METHODS

=over 4

=item tag (ARGS)

Store issued tags for later processing.

=cut

sub tag {

    my ($self, @args) = @_;

    push(@{$self->found}, [@args]);

    return;
}

=item issue_tags

Issue tags.

=cut

sub issue_tags {

    my ($self, @args) = @_;

    Lintian::Tags::tag @{$_} for @{$self->found};
    $self->_set_found([]);

    return;
}

has found => (is => 'rwp', default => sub { [] });

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

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

package Lintian::Info::Changelog::Version;

use strict;
use warnings;
use v5.16;

use Carp;
use Moo;

use constant EMPTY => q{};

=head1 NAME

Lintian::Info::Changelog::Version -- Parse a literal version string into its constituents

=head1 SYNOPSIS

 use Lintian::Info::Changelog::Version;

 my $version = Lintian::Info::Changelog::Version->new;
 $version->set('1.2.3-4', undef);

=head1 DESCRIPTION

A class for parsing literal version strings

=head1 CLASS METHODS

=over 4

=item new ()

Creates a new Lintian::Info::Changelog::Version object.

=cut

=back

=head1 INSTANCE METHODS

=over 4

=item set (LITERAL, NATIVE)

Set the various members in the Lintian::Info::Changelog::Version object
using the LITERAL version string and the NATIVE boolean selector.

=cut

sub set {

    my ($self, $literal, $native) = @_;

    croak 'Native flag required for version parsing'
      unless defined $native;

    my $epoch_pattern      = qr/([0-9]+)/;
    my $upstream_pattern   = qr/([A-Za-z0-9.+\-~]+?)/;
    my $maintainer_revision_pattern     = qr/([A-Za-z0-9.+~]+?)/;
    my $source_nmu_pattern = qr/([A-Za-z0-9.+~]+)/;
    my $bin_nmu_pattern    = qr/([0-9]+)/;

    my $source_pattern;

    # these capture three matches each
    $source_pattern
      = qr/$upstream_pattern/
      . qr/(?:-$maintainer_revision_pattern(?:\.$source_nmu_pattern)?)?/
      if !$native;
    $source_pattern
      = qr/()/
      . qr/$maintainer_revision_pattern/
      . qr/(?:\+nmu$source_nmu_pattern)?/
      if $native;

    my $pattern
      = qr/^/
      . qr/(?:$epoch_pattern:)?/
      . qr/$source_pattern/
      . qr/(?:\+b$bin_nmu_pattern)?/. qr/$/;

    my ($epoch, $upstream, $maintainer_revision, $source_nmu, $binary_nmu)
      = ($literal =~ $pattern);

    my $debian_source = $maintainer_revision // EMPTY;

    $debian_source .= "+nmu$source_nmu"
      if $native && length $source_nmu;
    $debian_source
      = $maintainer_revision . (length $source_nmu ? ".$source_nmu" : EMPTY)
      if !$native && length $maintainer_revision;

    my $debian_no_epoch
      = $debian_source . (length $binary_nmu ? "+b$binary_nmu" : EMPTY);

    my $no_epoch= (length $upstream ? "$upstream-" : EMPTY). $debian_no_epoch;

    my $reconstructed= (length $epoch ? "$epoch:" : EMPTY). $no_epoch;

    croak "Failed to parse package version: $reconstructed ne $literal"
      unless $reconstructed eq $literal;

    $self->_set_literal($literal // EMPTY);
    $self->_set_epoch($epoch // EMPTY);
    $self->_set_no_epoch($no_epoch // EMPTY);
    $self->_set_upstream($upstream // EMPTY);
    $self->_set_maintainer_revision($maintainer_revision // EMPTY);
    $self->_set_debian_source($debian_source // EMPTY);
    $self->_set_debian_no_epoch($debian_no_epoch // EMPTY);
    $self->_set_source_nmu($source_nmu // EMPTY);
    $self->_set_binary_nmu($binary_nmu // EMPTY);

    return;
}

has literal => (is => 'rwp',);

has epoch => (is => 'rwp',);

has no_epoch => (is => 'rwp',);

has upstream => (is => 'rwp',);

has maintainer_revision => (is => 'rwp',);

has debian_source => (is => 'rwp',);

has debian_no_epoch => (is => 'rwp',);

has source_nmu => (is => 'rwp',);

has binary_nmu => (is => 'rwp',);

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

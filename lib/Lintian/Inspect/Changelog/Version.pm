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

package Lintian::Inspect::Changelog::Version;

use v5.20;
use warnings;
use utf8;

use Carp;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Inspect::Changelog::Version -- Parse a literal version string into its constituents

=head1 SYNOPSIS

 use Lintian::Inspect::Changelog::Version;

 my $version = Lintian::Inspect::Changelog::Version->new;
 $version->set('1.2.3-4', undef);

=head1 DESCRIPTION

A class for parsing literal version strings

=head1 CLASS METHODS

=over 4

=item new ()

Creates a new Lintian::Inspect::Changelog::Version object.

=cut

=back

=head1 INSTANCE METHODS

=over 4

=item set (LITERAL, NATIVE)

Set the various members in the Lintian::Inspect::Changelog::Version object
using the LITERAL version string and the NATIVE boolean selector.

=cut

sub set {

    my ($self, $literal, $native) = @_;

    croak 'Literal version string required for version parsing'
      unless defined $literal;

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

    $epoch //= EMPTY;
    $upstream //= EMPTY;
    $maintainer_revision //= EMPTY;
    $source_nmu //= EMPTY;
    $binary_nmu //= EMPTY;

    my $source_nmu_string = EMPTY;

    $source_nmu_string = ($native ? "+nmu$source_nmu" : ".$source_nmu")
      if length $source_nmu;

    my $debian_source = $maintainer_revision . $source_nmu_string;

    my $debian_no_epoch
      = $debian_source . (length $binary_nmu ? "+b$binary_nmu" : EMPTY);

    my $upstream_string = (length $upstream ? "$upstream-" : EMPTY);

    my $no_epoch= $upstream_string . $debian_no_epoch;

    my $epoch_string = (length $epoch ? "$epoch:" : EMPTY);

    my $reconstructed= $epoch_string . $no_epoch;

    croak "Failed to parse package version: $reconstructed ne $literal"
      unless $reconstructed eq $literal;

    $self->_set_literal($literal);
    $self->_set_epoch($epoch);
    $self->_set_no_epoch($no_epoch);
    $self->_set_upstream($upstream);
    $self->_set_maintainer_revision($maintainer_revision);
    $self->_set_debian_source($debian_source);
    $self->_set_debian_no_epoch($debian_no_epoch);
    $self->_set_source_nmu($source_nmu);
    $self->_set_binary_nmu($binary_nmu);

    my $without_source_nmu
      = $epoch_string . $upstream_string . $maintainer_revision;

    $self->_set_without_source_nmu($without_source_nmu);

    my $backport_pattern = qr/^(.*)[+~]deb(\d+)u(\d+)$/;

    my ($debian_without_backport, $backport_release, $backport_revision)
      = ($self->maintainer_revision =~ $backport_pattern);

    $debian_without_backport //= $maintainer_revision;
    $backport_release //= EMPTY;
    $backport_revision //= EMPTY;

    $self->_set_debian_without_backport($debian_without_backport);
    $self->_set_backport_release($backport_release);
    $self->_set_backport_revision($backport_revision);

    my $without_backport
      = $epoch_string . $upstream_string . $debian_without_backport;

    $self->_set_without_backport($without_backport);

    return;
}

=item literal

=item epoch

=item no_epoch

=item upstream

=item maintainer_revision

=item debian_source

=item debian_no_epoch

=item source_nmu

=item binary_nmu

=item without_source_nmu

=item debian_without_backport

=item backport_release

=item backport_revision

=item without_backport

=cut

has literal => (is => 'rwp', default => EMPTY);

has epoch => (is => 'rwp', default => EMPTY);

has no_epoch => (is => 'rwp', default => EMPTY);

has upstream => (is => 'rwp', default => EMPTY);

has maintainer_revision => (is => 'rwp', default => EMPTY);

has debian_source => (is => 'rwp', default => EMPTY);

has debian_no_epoch => (is => 'rwp', default => EMPTY);

has source_nmu => (is => 'rwp', default => EMPTY);

has binary_nmu => (is => 'rwp', default => EMPTY);

has without_source_nmu => (is => 'rwp', default => EMPTY);

has debian_without_backport => (is => 'rwp', default => EMPTY);

has backport_release => (is => 'rwp', default => EMPTY);

has backport_revision => (is => 'rwp', default => EMPTY);

has without_backport => (is => 'rwp', default => EMPTY);

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

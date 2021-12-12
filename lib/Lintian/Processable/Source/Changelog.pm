# -*- perl -*- Lintian::Processable::Source::Changelog -- access to collected changelog data
#
# Copyright © 1998 Richard Braakman
# Copyright © 2019-2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Processable::Source::Changelog;

use v5.20;
use warnings;
use utf8;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Source::Changelog - access to collected changelog data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Source::Changelog provides an interface to changelog data.

=head1 INSTANCE METHODS

=over 4

=item changelog_item

=cut

has changelog_item => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $item = $self->patched->resolve_path('debian/changelog');

        return $item;
    });

=item changelog

Returns the changelog of the source package as a Parse::DebianChangelog
object, or an empty object if the changelog cannot be resolved safely.

=cut

has changelog => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $changelog = Lintian::Changelog->new;

        my $item = $self->changelog_item;

        # return empty changelog
        return $changelog
          unless defined $item && $item->is_open_ok;

        return $changelog
          unless $item->is_valid_utf8;

        $changelog->parse($item->decoded_utf8);

        return $changelog;
    });

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# -*- perl -*- Lintian::Processable::Source::Overrides
#
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

package Lintian::Processable::Source::Overrides;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(first_value);

use Moo::Role;
use namespace::clean;

with 'Lintian::Processable::Overrides';

=head1 NAME

Lintian::Processable::Source::Overrides - access to override data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Source::Overrides provides an interface to overrides.

=head1 INSTANCE METHODS

=over 4

=item override_file

=cut

has override_file => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # prefer source/lintian-overrides to source.lintian-overrides
        my @candidates = ('debian/source/lintian-overrides',
            'debian/source.lintian-overrides');

        # pick the first
        my $override_item= first_value { defined }
        map { $self->patched->lookup($_) } @candidates;

        return $override_item;
    });

=item overrides

=cut

has overrides => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return {}
          unless defined $self->override_file;

        my $contents = $self->override_file->decoded_utf8;

        return $self->parse_overrides($contents);
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

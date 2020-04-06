# -*- perl -*- Lintian::Processable::Diffstat -- access to collected diffstat data
#
# Copyright © 2019 Felix Lechner
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

package Lintian::Processable::Diffstat;

use v5.20;
use warnings;
use utf8;
use autodie;

use Path::Tiny;

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Diffstat - access to collected diffstat data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Diffstat provides an interface to diffstat data.

=head1 INSTANCE METHODS

=over 4

=item diffstat

Returns the path to diffstat output run on the Debian packaging diff
(a.k.a. the "diff.gz") for 1.0 non-native packages.  For source
packages without a "diff.gz" component, this returns the path to an
empty file (this may be a device like /dev/null).

Needs-Info requirements for using I<diffstat>: diffstat

=item saved_diffstat

Returns the cached diffstat information.

=cut

has saved_diffstat => (is => 'rw', default => EMPTY);

sub diffstat {
    my ($self) = @_;

    return $self->saved_diffstat
      if length $self->saved_diffstat;

    my $dstat = path($self->groupdir)->child('diffstat')->stringify;

    $dstat = '/dev/null'
      unless -e $dstat;

    $self->saved_diffstat($dstat);

    return $self->saved_diffstat;
}

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

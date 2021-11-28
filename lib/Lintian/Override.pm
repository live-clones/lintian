# -*- perl -*- Lintian::Override
#
# Copyright © 2021 Felix Lechner
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

package Lintian::Override;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $EMPTY => q{};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Override - access to override data

=head1 SYNOPSIS

    use Lintian::Override;

=head1 DESCRIPTION

Lintian::Override provides access to override data.

=head1 INSTANCE METHODS

=over 4

=item tag_name
=item architectures

=item pattern
=item regex

=item comments
=item position

=cut

has tag_name => (is => 'rw', default => $EMPTY);
has architectures => (is => 'rw', default => sub { [] });

has pattern => (is => 'rw', default => $EMPTY);
has regex => (is => 'rw');

has comments => (is => 'rw', default => sub { [] });
has position => (is => 'rw');

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

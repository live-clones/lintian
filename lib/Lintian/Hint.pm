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

package Lintian::Hint;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };

=head1 NAME

Lintian::Hint -- Common facilities for Lintian tags found and to be issued

=head1 SYNOPSIS

 use Moo;
 use namespace::clean;

 with 'Lintian::Hint';

=head1 DESCRIPTION

Common facilities for Lintian tags found and to be issued

=head1 INSTANCE METHODS

=over 4

=item arguments
=item tag
=item override
=item screen
=item processable

=item context

Calculate the string representation commonly referred to as 'context'.

=cut

has arguments => (is => 'rw', default => sub { [] });
has tag => (is => 'rw');
has override => (is => 'rw');
has screen => (is => 'rw');
has processable => (is => 'rw');

sub context {
    my ($self) = @_;

    # skip empty arguments
    my @relevant = grep { length } @{$self->arguments};

    # concatenate with spaces
    my $context = join($SPACE, @relevant) // $EMPTY;

    # escape newlines; maybe add others
    $context =~ s/\n/\\n/g;

    return $context;
}

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

# Copyright (C) 2019-2021 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Hint::Annotated;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Hint';

=head1 NAME

Lintian::Hint::Annotated - standard tag with arguments concatenated by space

=head1 SYNOPSIS

    use Lintian::Hint::Annotated;

=head1 DESCRIPTION

Provides a standard tag whose arguments are concatenated by a space.

=head1 INSTANCE METHODS

=over 4

=item note

=cut

has note => (is => 'rw', default => $EMPTY);

=item context

=cut

sub context {
    my ($self) = @_;

    return $self->note;
}

=back

=cut

1;

__END__

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# -*- perl -*-
# Lintian::Tag::Override -- Interface to Lintian overrides

# Copyright (C) 2011 Niels Thykier
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

package Lintian::Tag::Override;

use strict;
use warnings;

use Lintian::Data;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Tag::Override -- Representation of a Lintian Override

=head1 SYNOPSIS

 use Lintian::Tag::Override;
 
 my $data = {
    'comments' => ['some', 'multi-line', 'comments']
 };
 my $override = Lintian::Tag::Override->new('unused-override', $data);
 my $comments = $override->comments;
 if ($override->overrides("some extra") ) {
     # do something
 }

=head1 DESCRIPTION

Represents a Lintian Override.

=head1 METHODS

=over 4

=item $override->tag

Returns the name of the tag.

=item $override->arch

Architectures this override applies too (not really used).

=item $override->comments

A list of comments (each item is a separate line).
Returns a list of lines that makes up the comments for this override.

Do not modify the contents of this list.

=item $override->extra

The extra part of the override.  If it contains a "*" is will
considered a pattern. Returns the extra of this tag
(or the empty string, if there is no extra).

=item $override->is_pattern

Returns a truth value if the extra is a pattern.

=item $override->pattern

Hold the pattern if extra is a pattern.

=cut

has tag => (is => 'rw');
has arch => (is => 'rw', default => 'any');
has comments => (is => 'rw');
has extra => (is => 'rw', default => EMPTY);
has pattern => (is => 'rw', default => EMPTY);
has is_pattern => (is => 'rw', default => 0);

=item $override->overrides($extra)

Returns a truth value if this override applies to this extra.

=cut

sub overrides {
    my ($self, $testextra) = @_;

    $testextra //= EMPTY;

    # overrides without extra apply to all tags of its kind
    return 1
      unless length $self->extra;

    return 1
      if $testextra eq $self->extra // EMPTY;

    if ($self->is_pattern) {

        my $pat = $self->pattern;

        return 1
          if $testextra =~ m/^$pat\z/;
    }

    return 0;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintian::Tags>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

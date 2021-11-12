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

package Lintian::Hint::Bearer;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Hint::Standard;

use Moo::Role;
use namespace::clean;

const my $SPACE => q{ };

=head1 NAME

Lintian::Hint::Bearer -- Facilities for objects receiving Lintian tags

=head1 SYNOPSIS

use Moo;
use namespace::clean;

 with('Lintian::Hint::Bearer');

=head1 DESCRIPTION

A class for collecting Lintian tags as they are found

=head1 INSTANCE METHODS

=over 4

=item profile
=item context_tracker

=cut

has profile => (is => 'rw');
has context_tracker => (is => 'rw', default => sub { {} });

=item hint (ARGS)

Store found tags for later processing.

=cut

sub hint {
    my ($self, $tagname, @context_components) = @_;

    my @meaningful = grep { length } @context_components;

    # trim both ends of each item
    s/^\s+|\s+$//g for @meaningful;

    my $tag = $self->profile->get_tag($tagname);
    unless (defined $tag) {

        warn encode_utf8("tried to issue unknown tag: $tagname\n");
        return;
    }

    # skip disabled tags
    return
      unless $self->profile->tag_is_enabled($tagname);

    my $context_string = join($SPACE, @meaningful);
    if (exists $self->context_tracker->{$tagname}{$context_string}) {

        my $checkname = $tag->check;
        warn encode_utf8(
"tried to issue duplicate hint in check $checkname: $tagname $context_string\n"
        );
        return;
    }

    $self->context_tracker->{$tagname}{$context_string} = 1;

    my $hint = Lintian::Hint::Standard->new;

    $hint->tag($tag);
    $hint->arguments(\@meaningful);

    push(@{$self->hints}, $hint);

    return;
}

=item hints

=cut

has hints => (is => 'rw', default => sub { [] });

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

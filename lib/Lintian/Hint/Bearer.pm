# Copyright © 2019-2021 Felix Lechner <felix.lechner@lease-up.com>
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

use Lintian::Hint::Pointed;
use Lintian::Hint::Standard;

const my $EMPTY => q{};
const my $SPACE => q{ };

use Moo::Role;
use namespace::clean;

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
=item hints

=cut

has profile => (is => 'rw');
has context_tracker => (is => 'rw', default => sub { {} });
has hints => (is => 'rw', default => sub { [] });

=item pointed_hint

=cut

sub pointed_hint {
    my ($self, $tag_name, $pointer, @notes) = @_;

    my $tag = $self->profile->get_tag($tag_name);
    unless (defined $tag) {

        warn encode_utf8("tried to issue unknown tag: $tag_name\n");
        return;
    }

    # skip disabled tags
    return
      unless $self->profile->tag_is_enabled($tag_name);

    my $hint = Lintian::Hint::Pointed->new;

    $hint->tag($tag);
    $hint->note(stringify(@notes));
    $hint->pointer($pointer);

    my $context_string = $hint->context;
    if (exists $self->context_tracker->{$tag_name}{$context_string}) {

        my $check_name = $tag->check;
        warn encode_utf8(
"tried to issue duplicate hint in check $check_name: $tag_name $context_string\n"
        );
        return;
    }

    $self->context_tracker->{$tag_name}{$context_string} = 1;

    push(@{$self->hints}, $hint);

    return;
}

=item hint

=cut

sub hint {
    my ($self, $tag_name, @notes) = @_;

    my $tag = $self->profile->get_tag($tag_name);
    unless (defined $tag) {

        warn encode_utf8("tried to issue unknown tag: $tag_name\n");
        return;
    }

    # skip disabled tags
    return
      unless $self->profile->tag_is_enabled($tag_name);

    my $hint = Lintian::Hint::Standard->new;

    $hint->tag($tag);
    $hint->note(stringify(@notes));

    my $context_string = $hint->context;
    if (exists $self->context_tracker->{$tag_name}{$context_string}) {

        my $check_name = $tag->check;
        warn encode_utf8(
"tried to issue duplicate hint in check $check_name: $tag_name $context_string\n"
        );
        return;
    }

    $self->context_tracker->{$tag_name}{$context_string} = 1;

    push(@{$self->hints}, $hint);

    return;
}

no namespace::clean;

=item stringify

=cut

sub stringify {
    my (@arguments) = @_;

    # skip empty arguments
    my @meaningful = grep { length } @arguments;

    # trim both ends of each item
    s{^ \s+ | \s+ $}{}gx for @meaningful;

    # concatenate with spaces
    my $text = join($SPACE, @meaningful) // $EMPTY;

    # escape newlines; maybe add others
    $text =~ s{\n}{\\n}g;

    return $text;
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

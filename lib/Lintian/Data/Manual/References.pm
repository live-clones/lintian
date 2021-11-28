# -*- perl -*-
#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2009 Russ Allbery
# Copyright © 2020 Felix Lechner
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

package Lintian::Data::Manual::References;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Output::Markdown qw(markdown_authority);

use Moo;
use namespace::clean;

with 'Lintian::Data';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

const my $THREE_PARTS => 3;

=head1 NAME

Lintian::Data::Manual::References - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Manual::References;

=head1 DESCRIPTION

Lintian::Data::Manual::References provides a way to load data files for
manual references.

=head1 CLASS METHODS

=over 4

=item title

=item location

=item separator

=item accumulator

=cut

has title => (
    is => 'rw',
    default => 'Manual References'
);

has location => (
    is => 'rw',
    default => 'output/manual-references'
);

has separator => (
    is => 'rw',
    default => sub { qr/::/ });

has accumulator => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return sub {
            my ($key, $remainder, $previous) = @_;

            # use previous hashref, if available
            $previous //= {};

            my ($section, $title, $url)
              = split($self->separator, $remainder, $THREE_PARTS);

            $previous->{$section}{title} = $title;
            $previous->{$section}{url} = $url;

            return $previous;
        };
    });

=item markdown_citation

=cut

sub markdown_citation {
    my ($self, $volume, $section_key) = @_;

    return $EMPTY
      unless $self->recognizes($volume);

    my $entry = $self->value($volume);

    # start with the citation to the overall manual.
    my $volume_title = $entry->{$EMPTY}{title};
    my $volume_url   = $entry->{$EMPTY}{url};

    # may not be defined
    my $section_title = $entry->{$section_key}{title};
    my $section_url   = $entry->{$section_key}{url};

    return markdown_authority(
        $volume_title, $volume_url,$section_key,
        $section_title, $section_url
    );
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

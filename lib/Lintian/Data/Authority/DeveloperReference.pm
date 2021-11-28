# -*- perl -*-
#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2009 Russ Allbery
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Data::Authority::DeveloperReference;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;

use Lintian::Output::Markdown qw(markdown_authority);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $UNDERSCORE => q{_};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

const my $TWO_PARTS => 2;

const my $VOLUME_KEY => $UNDERSCORE;

use Moo;
use namespace::clean;

with 'Lintian::Data';

=head1 NAME

Lintian::Data::Authority::DeveloperReference - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Authority::DeveloperReference;

=head1 DESCRIPTION

Lintian::Data::Authority::DeveloperReference provides a way to load data files for
manual references.

=head1 CLASS METHODS

=over 4

=item title

=item shorthand

=item location

=item separator

=item accumulator

=cut

has title => (
    is => 'rw',
    default => q{Developer's Reference}
);

has shorthand => (
    is => 'rw',
    default => 'devref'
);

has location => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return 'authority/' . $self->shorthand;
    });

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

            return undef
              if defined $previous;

            my ($title, $url)= split($self->separator, $remainder, $TWO_PARTS);

            my %entry;
            $entry{title} = $title;
            $entry{url} = $url;

            return \%entry;
        };
    });

=item markdown_citation

=cut

sub markdown_citation {
    my ($self, $section_key) = @_;

    croak "Invalid section $section_key"
      if $section_key eq $VOLUME_KEY;

    my $volume_entry = $self->value($VOLUME_KEY);

    # start with the citation to the overall manual.
    my $volume_title = $volume_entry->{title};
    my $volume_url   = $volume_entry->{url};

    my $section_title;
    my $section_url;

    if ($self->recognizes($section_key)) {

        my $section_entry = $self->value($section_key);

        $section_title = $section_entry->{title};
        $section_url   = $section_entry->{url};
    }

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

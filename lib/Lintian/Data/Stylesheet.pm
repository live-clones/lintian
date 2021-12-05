# -*- perl -*-
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

package Lintian::Data::Stylesheet;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use HTTP::Tiny;
use List::SomeUtils qw(first_value);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

const my $EMPTY => q{};
const my $SLASH => q{/};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Data::Stylesheet - Lintian interface to CSS style sheets

=head1 SYNOPSIS

    use Lintian::Data::Stylesheet;

=head1 DESCRIPTION

This module provides a way to load data files to CSS style sheets

=head1 INSTANCE METHODS

=over 4

=item title

=item location

=item C<css>

=cut

has title => (
    is => 'rw',
    default => 'Lintian CSS Style Sheet'
);

has location => (
    is => 'rw',
    default => 'stylesheets/lintian.css'
);

has css => (is => 'rw', default => $EMPTY);

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    croak encode_utf8('Unknown data file: ' . $self->location)
      unless length $path;

    my $style_sheet = path($path)->slurp_utf8;

    $self->css($style_sheet);

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    my $css_url = 'https://lintian.debian.org/stylesheets/lintian.css';

    my $response = HTTP::Tiny->new->get($css_url);
    die encode_utf8("Failed to get $css_url!\n")
      unless $response->{success};

    my $style_sheet = $response->{content};

    my $data_path = "$basedir/" . $self->location;
    my $parent_dir = path($data_path)->parent->stringify;
    path($parent_dir)->mkpath
      unless -e $parent_dir;

    # already in UTF-8
    path($data_path)->spew($style_sheet);

    return 1;
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

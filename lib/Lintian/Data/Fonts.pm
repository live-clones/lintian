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

package Lintian::Data::Fonts;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use File::Basename;
use JSON::MaybeXS;
use List::SomeUtils qw(first_value uniq);
use Path::Tiny;
use PerlIO::gzip;
use Time::Piece;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Data';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};

const my $NEWLINE => qq{\n};

=head1 NAME

Lintian::Data::Fonts - Lintian interface for fonts.

=head1 SYNOPSIS

    use Lintian::Data::Fonts;

=head1 DESCRIPTION

This module provides a way to load data files for fonts.

=head1 INSTANCE METHODS

=over 4

=item title

=item location

=item preamble

=item installable_names_by_font

=cut

has title => (
    is => 'rw',
    default => 'Fonts Available for Installation'
);

has location => (
    is => 'rw',
    default => 'fonts.json'
);

has preamble => (is => 'rw');
has installable_names_by_font => (is => 'rw', default => sub { {} });

=item all

=cut

sub all {
    my ($self) = @_;

    return keys %{$self->installable_names_by_font};
}

=item installed_by

=cut

sub installed_by {
    my ($self, $name) = @_;

    my $lowercase = lc $name;

    return ()
      unless exists $self->installable_names_by_font->{$lowercase};

    my @installed_by = @{$self->installable_names_by_font->{$lowercase} // []};

    return @installed_by;
}

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    croak encode_utf8('Unknown data file: ' . $self->location)
      unless length $path;

    my $json = path($path)->slurp;
    my $data = decode_json($json);

    $self->preamble($data->{preamble});

    my %fonts = %{$data->{fonts} // {}};
    my %installable_names_by_font;

    for my $name (keys %fonts) {

        my @installable_names;
        push(@installable_names, @{$fonts{$name}{installed_by}});

        $installable_names_by_font{$name} = \@installable_names;
    }

    $self->installable_names_by_font(\%installable_names_by_font);

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    # neutral sort order
    local $ENV{LC_ALL} = 'C';

    my $port = 'amd64';

    my %fonts;

    for my $installable_architecture ('all', $port) {

        my $local_path
          = $archive->contents_gz('sid', 'main', $installable_architecture);

        open(my $fd, '<:gzip', $local_path)
          or die encode_utf8("Cannot open $local_path.");

        while (my $line = <$fd>) {

            chomp $line;

            my ($path, $finder) = split($SPACE, $line, 2);
            next
              unless length $path
              && length $finder;

            if ($path =~ m{ [.] (?:[to]tf|pfb) $}ix) {

                my @locations = split(m{,}, $finder);
                for my $location (@locations) {

                    my ($section, $installable_name)
                      = split(m{/}, $location, 2);

        # Record only packages starting with ttf-, otf-, t1-, xfonts- or fonts-
                    next
                      unless $installable_name
                      =~ m{^ (?: [to]tf | t1 | x?fonts ) - }x;

                    my $basename = basename($path);
                    my $lowercase = lc $basename;

                    $fonts{$lowercase}{installed_by} //= [];
                    push(@{$fonts{$lowercase}{installed_by}},
                        $installable_name);
                }

                next;
            }
        }

        close $fd;
    }

    my %preamble;
    $preamble{title} = $self->title;
    $preamble{last_update} = gmtime->datetime . 'Z';

    my %all;
    $all{preamble} = \%preamble;
    $all{fonts} = \%fonts;

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    my $json = $encoder->encode(\%all);

    my $datapath = "$basedir/" . $self->location;
    my $parentdir = path($datapath)->parent->stringify;
    path($parentdir)->mkpath
      unless -e $parentdir;

    # already in UTF-8
    path($datapath)->spew($json);

    return;
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

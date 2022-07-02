# files/locales -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2013 Niels Thykier <niels@thykier.net>
# Copyright (C) 2019 Adam D. Barratt <adam@adam-barratt.org.uk>
# Copyright (C) 2021 Felix Lechner
#
# Based in part on a shell script that was:
#   Copyright (C) 2010 Raphael Geissert <atomo64@gmail.com>
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

package Lintian::Check::Files::Locales;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use JSON::MaybeXS;
use List::SomeUtils qw(first_value);
use Path::Tiny;

const my $EMPTY => q{};

const my $ARROW => q{->};

const my $RESERVED => $EMPTY;
const my $SPECIAL => q{S};

const my %CONFUSING_LANGUAGES => (
    # Albanian is sq, not al:
    'al' => 'sq',
    # Chinese is zh, not cn:
    'cn' => 'zh',
    # Czech is cs, not cz:
    'cz' => 'cs',
    # Danish is da, not dk:
    'dk' => 'da',
    # Greek is el, not gr:
    'gr' => 'el',
    # Indonesian is id, not in:
    'in' => 'id',
);

const my %CONFUSING_COUNTRIES => (
    # UK != GB
    'en_UK' => 'en_GB',
);
use Moo;
use namespace::clean;

with 'Lintian::Check';

has ISO639_3_by_alpha3 => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        local $ENV{LC_ALL} = 'C';

        my $bytes = path('/usr/share/iso-codes/json/iso_639-3.json')->slurp;
        my $json = decode_json($bytes);

        my %iso639_3;
        for my $entry (@{$json->{'639-3'}}) {

            my $alpha_3 = $entry->{alpha_3};

            $iso639_3{$alpha_3} = $entry;
        }

        return \%iso639_3;
    }
);

has LOCALE_CODES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        local $ENV{LC_ALL} = 'C';

        my %CODES;
        for my $entry (values %{$self->ISO639_3_by_alpha3}) {

            my $type = $entry->{type};

            # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=692548#10
            next
              if $type eq $RESERVED || $type eq $SPECIAL;

            # also have two letters, ISO 639-1
            my $two_letters;
            $two_letters = $entry->{alpha_2}
              if exists $entry->{alpha_2};

            $CODES{$two_letters} = $EMPTY
              if length $two_letters;

            # three letters, ISO 639-2
            my $three_letters = $entry->{alpha_3};

            # a value indicates that two letters are preferred
            $CODES{$three_letters} = $two_letters || $EMPTY;
        }

        return \%CODES;
    }
);

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_dir;

    return
      unless $item->name =~ m{^ usr/share/locale/ ([^/]+) / $}x;

    my $folder = $1;

    # without encoding
    my ($with_country) = split(m/[.@]/, $folder);

    # special exception
    return
      if $with_country eq 'l10n';

    # without country code
    my ($two_or_three, $country) = split(m/_/, $with_country);

    $country //= $EMPTY;

    return
      unless length $two_or_three;

    # check some common language errors
    if (exists $CONFUSING_LANGUAGES{$two_or_three}) {

        my $fixed = $folder;
        $fixed =~ s{^ $two_or_three }{$CONFUSING_LANGUAGES{$two_or_three}}x;

        $self->pointed_hint('incorrect-locale-code', $item->pointer, $folder,
            $ARROW,$fixed);
        return;
    }

    # check some common country errors
    if (exists $CONFUSING_COUNTRIES{$with_country}) {

        my $fixed = $folder;
        $fixed =~ s{^ $with_country }{$CONFUSING_COUNTRIES{$with_country}}x;

        $self->pointed_hint('incorrect-locale-code', $item->pointer, $folder,
            $ARROW,$fixed);
        return;
    }

    # check known codes
    if (exists $self->LOCALE_CODES->{$two_or_three}) {

        my $replacement = $self->LOCALE_CODES->{$two_or_three};
        return
          unless length $replacement;

        # a value indicates that two letters are preferred
        my $fixed = $folder;
        $fixed =~ s{^ $two_or_three }{$replacement}x;

        $self->pointed_hint('incorrect-locale-code', $item->pointer, $folder,
            $ARROW,$fixed);

        return;
    }

    $self->pointed_hint('unknown-locale-code', $item->pointer, $folder);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

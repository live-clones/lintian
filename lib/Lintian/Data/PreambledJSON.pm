# -*- perl -*-

# Copyright (C) 2021 Felix Lechner
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

package Lintian::Data::PreambledJSON;

use v5.20;
use warnings;
use utf8;

use Carp qw(carp);
use Const::Fast;
use JSON::MaybeXS;
use Path::Tiny;
use Time::Piece;
use Unicode::UTF8 qw(encode_utf8);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};

const my $PREAMBLE => q{preamble};
const my $TITLE => q{title};
const my $CARGO => q{cargo};

=encoding utf-8

=head1 NAME

Lintian::Data::PreambledJSON -- Data in preambled JSON format

=head1 SYNOPSIS

 use Lintian::Data::PreambledJSON;

=head1 DESCRIPTION

Routines for access and management of preambled JSON data files.

=head1 INSTANCE METHODS

=over 4

=item last_modified

=cut

has cargo => (
    is => 'rw',
    coerce => sub { my ($scalar) = @_; return ($scalar // $EMPTY); }
);

=item read_file

=cut

sub read_file {
    my ($self, $path, $double_reference) = @_;

    if (!length $path || !-e $path) {

        carp encode_utf8("Unknown data file: $path");
        return 0;
    }

    my $json = path($path)->slurp;
    my $data = decode_json($json);

    my %preamble = %{$data->{$PREAMBLE}};
    my $stored_title = $preamble{$TITLE};
    my $storage_key = $preamble{$CARGO};

    unless (length $stored_title && length $storage_key) {
        warn encode_utf8("Please refresh data file $path: invalid format");
        return 0;
    }

    unless ($stored_title eq $self->title) {
        warn encode_utf8(
            "Please refresh data file $path: wrong title $stored_title");
        return 0;
    }

    if ($storage_key eq $PREAMBLE) {
        warn encode_utf8(
            "Please refresh data file $path: disallowed cargo key $storage_key"
        );
        return 0;
    }

    if (!exists $data->{$storage_key}) {
        warn encode_utf8(
            "Please refresh data file $path: cargo key $storage_key not found"
        );
        return 0;
    }

    ${$double_reference} = $data->{$storage_key};

    return 1;
}

=item write_file

=cut

sub write_file {
    my ($self, $storage_key, $reference, $path) = @_;

    die
"Cannot write preambled JSON data file $path: disallowed cargo key $storage_key"
      if $storage_key eq $PREAMBLE;

    my %preamble;
    $preamble{$TITLE} = $self->title;
    $preamble{$CARGO} = $storage_key;

    my %combined;
    $combined{$PREAMBLE} = \%preamble;
    $combined{$storage_key} = $reference;

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    my $json = $encoder->encode(\%combined);

    my $parentdir = path($path)->parent->stringify;
    path($parentdir)->mkpath
      unless -e $parentdir;

    # already in UTF-8
    path($path)->spew($json);

    return 1;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

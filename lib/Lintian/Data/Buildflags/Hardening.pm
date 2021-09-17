# -*- perl -*-

# Copyright © 2011-2012 Niels Thykier <niels@thykier.net>
#  - Based on a shell script by Raphael Geissert <atomo64@gmail.com>
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

package Lintian::Data::Buildflags::Hardening;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use JSON::MaybeXS;
use List::SomeUtils qw(first_value uniq);
use Path::Tiny;
use Time::Piece;
use Unicode::UTF8 qw(decode_utf8 encode_utf8);

use Lintian::Deb822::File;
use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

const my $SLASH => q{/};

=encoding utf-8

=head1 NAME

Lintian::Data::Buildflags::Hardening -- Lintian API for hardening build flags

=head1 SYNOPSIS

 use Lintian::Data::Buildflags::Hardening;

=head1 DESCRIPTION

Lintian API for hardening build flags.

=head1 INSTANCE METHODS

=over 4

=item location

=item preamble

=item recommended_features

=cut

has location => (
    is => 'rw',
    default => 'buildflags/hardening.json'
);

has preamble => (is => 'rw');
has recommended_features => (is => 'rw');

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
    $self->recommended_features($data->{'recommended-features'});

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $basedir) = @_;

    # find all recommended hardening features
    local $ENV{LC_ALL} = 'C';
    local $ENV{DEB_BUILD_MAINT_OPTIONS} = 'hardening=+all';

    my $version_output= decode_utf8(safe_qx('dpkg-architecture', '--version'));
    my ($dpkg_version) = split(/\n/, $version_output);

    # retain only the version number
    $dpkg_version =~ s/^.*\s(\S+)[.]$/$1/s;

    my @architectures
      = split(/\n/, decode_utf8(safe_qx('dpkg-architecture', '-L')));
    chomp for @architectures;

    my %recommended_features;
    for my $architecture (@architectures) {

        local $ENV{DEB_HOST_ARCH} = $architecture;

        my @command = qw{dpkg-buildflags --query-features hardening};
        my $feature_output = decode_utf8(safe_qx(@command));

        my $deb822 = Lintian::Deb822::File->new;
        my @sections = $deb822->parse_string($feature_output);

        my @enabled = grep { $_->value('Enabled') eq 'yes' } @sections;
        my @features = uniq map { $_->value('Feature') } @enabled;

        $recommended_features{$architecture} = [sort @features];
    }

    my %preamble;
    $preamble{title} = 'Hardening Flags From Dpkg';
    $preamble{'dpkg-version'} = $dpkg_version;
    $preamble{'last-update'} = gmtime->datetime . 'Z';

    my %all;
    $all{preamble} = \%preamble;
    $all{'recommended-features'} = \%recommended_features;

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

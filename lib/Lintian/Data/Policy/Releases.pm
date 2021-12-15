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

package Lintian::Data::Policy::Releases;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Date::Parse qw(str2time);
use List::SomeUtils qw(first_value);
use IPC::Run3;
use HTTP::Tiny;
use List::SomeUtils qw(minmax);
use List::UtilsBy qw(rev_nsort_by);
use Path::Tiny;
use Time::Moment;
use Unicode::UTF8 qw(decode_utf8 encode_utf8);

const my $SLASH => q{/};

const my $RELEASES => q{releases};

const my $WAIT_STATUS_SHIFT => 8;

use Moo;
use namespace::clean;

with 'Lintian::Data::PreambledJSON';

=head1 NAME

Lintian::Data::Policy::Releases - Lintian interface for policy releases

=head1 SYNOPSIS

    use Lintian::Data::Policy::Releases;

=head1 DESCRIPTION

This module provides a way to load data files for policy releases.

=head1 INSTANCE METHODS

=over 4

=item title

=item location

=item ordered_versions

=item by_version

=item max_dots

=cut

has title => (
    is => 'rw',
    default => 'Debian Policy Releases'
);

has location => (
    is => 'rw',
    default => 'debian-policy/releases.json'
);

has ordered_versions => (is => 'rw', default => sub { [] });
has by_version => (is => 'rw', default => sub { {} });
has max_dots => (is => 'rw');

=item latest_version

=cut

sub latest_version {
    my ($self) = @_;

    return $self->ordered_versions->[0];
}

=item normalize

=cut

sub normalize {
    my ($self, $version) = @_;

    my $have = $version =~ tr{\.}{};
    my $need = $self->max_dots - $have;

    $version .= '.0' for (1..$need);

    return $version;
}

=item is_known

=cut

sub is_known {
    my ($self, $version) = @_;

    my $normalized = $self->normalize($version);

    return exists $self->by_version->{$normalized};
}

=item epoch

=cut

sub epoch {
    my ($self, $version) = @_;

    my $normalized = $self->normalize($version);

    my $release = $self->by_version->{$normalized};
    return undef
      unless defined $release;

    return $release->{epoch};
}

=item author

=cut

sub author {
    my ($self, $version) = @_;

    my $normalized = $self->normalize($version);

    my $release = $self->by_version->{$normalized};
    return undef
      unless defined $release;

    return $release->{author};
}

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    my $reference;
    return 0
      unless $self->read_file($path, \$reference);

    my @releases = @{$reference // []};

    my @sorted = rev_nsort_by { $_->{epoch} } @releases;
    my @ordered_versions = map { $_->{version} } @sorted;
    $self->ordered_versions(\@ordered_versions);

    my @dot_count = map { tr{\.}{} } @ordered_versions;
    my (undef, $max_dots) = minmax @dot_count;
    $self->max_dots($max_dots);

    # normalize versions
    $_->{version} = $self->normalize($_->{version}) for @releases;

    my %by_version;
    $by_version{$_->{version}} = $_ for @releases;

    $self->by_version(\%by_version);

    return 1;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    my $changelog_url
      = 'https://salsa.debian.org/dbnpolicy/policy/-/raw/master/debian/changelog?inline=false';

    my $response = HTTP::Tiny->new->get($changelog_url);
    die encode_utf8("Failed to get $changelog_url!\n")
      unless $response->{success};

    my $tempfile_tiny = Path::Tiny->tempfile;
    $tempfile_tiny->spew($response->{content});

    my @command = (
        qw{dpkg-parsechangelog --format rfc822 --all --file},
        $tempfile_tiny->stringify
    );
    my $rfc822;
    my $stderr;
    run3(\@command, \undef, \$rfc822, \$stderr);
    my $dpkg_status = ($? >> $WAIT_STATUS_SHIFT);

    # already in UTF-8
    die $stderr
      if $dpkg_status;

    my $deb822 = Lintian::Deb822->new;
    my @sections = $deb822->parse_string(decode_utf8($rfc822));

    my @releases;
    for my $section (@sections) {

        my $epoch = str2time($section->value('Date'), 'GMT');
        my $moment = Time::Moment->from_epoch($epoch);
        my $timestamp = $moment->strftime('%Y-%m-%dT%H:%M:%S%Z');

        my @closes = sort { $a <=> $b } $section->trimmed_list('Closes');
        my @changes = split(/\n/, $section->text('Changes'));

        my %release;
        $release{version} = $section->value('Version');
        $release{timestamp} = $timestamp;
        $release{epoch} = $epoch;
        $release{closes} = \@closes;
        $release{changes} = \@changes;
        $release{author} = $section->value('Maintainer');

        push(@releases, \%release);
    }

    my @sorted = rev_nsort_by { $_->{epoch} } @releases;

    my $data_path = "$basedir/" . $self->location;
    my $write_status = $self->write_file($RELEASES, \@releases, $data_path);

    return $write_status;
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

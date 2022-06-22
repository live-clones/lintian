# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
# Copyright (C) 2018 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner
# Copyright (C) 2022 Axel Beckert
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

package Lintian::Data;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Data::Architectures;
use Lintian::Data::Archive::AutoRejection;
use Lintian::Data::Archive::Sections;
use Lintian::Data::Buildflags::Hardening;
use Lintian::Data::Debhelper::Addons;
use Lintian::Data::Debhelper::Commands;
use Lintian::Data::Debhelper::Levels;
use Lintian::Data::Fonts;
use Lintian::Data::InitD::VirtualFacilities;
use Lintian::Data::Policy::Releases;
use Lintian::Data::Provides::MailTransportAgent;
use Lintian::Data::Stylesheet;
use Lintian::Data::Traditional;

use Moo;
use namespace::clean;

with 'Lintian::Data::Authorities';

=head1 NAME

Lintian::Data - Data parser for Lintian

=head1 SYNOPSIS

 my $profile = Lintian::Data->new (vendor => 'debian');

=head1 DESCRIPTION

Lintian::Data handles finding, parsing and implementation of Lintian Data

=head1 INSTANCE METHODS

=over 4

=item vendor

=item data_paths

=item data_cache

=cut

has vendor => (is => 'rw');

has data_paths => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] }
);

has data_cache => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} }
);

=item load

=cut

sub load {
    my ($self, $location, $separator) = @_;

    croak encode_utf8('no data type specified')
      unless $location;

    unless (exists $self->data_cache->{$location}) {

        my $cache = Lintian::Data::Traditional->new;
        $cache->location($location);
        $cache->separator($separator);

        $cache->load($self->data_paths, $self->vendor);

        $self->data_cache->{$location} = $cache;
    }

    return $self->data_cache->{$location};
}

=item all_sources

=cut

sub all_sources {
    my ($self) = @_;

    my @sources = (
        $self->architectures,$self->auto_rejection,
        $self->debhelper_addons,$self->debhelper_commands,
        $self->debhelper_levels,$self->fonts,
        $self->hardening_buildflags,$self->mail_transport_agents,
        $self->policy_releases,$self->sections,
        $self->style_sheet,$self->virtual_initd_facilities
    );

    return @sources;
}

=item architectures

=cut

has architectures => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $architectures = Lintian::Data::Architectures->new;
        $architectures->load($self->data_paths, $self->vendor);

        return $architectures;
    }
);

=item auto_rejection

=cut

has auto_rejection => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $auto_rejection = Lintian::Data::Archive::AutoRejection->new;
        $auto_rejection->load($self->data_paths, $self->vendor);

        return $auto_rejection;
    }
);

=item debhelper_addons

=cut

has debhelper_addons => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $addons = Lintian::Data::Debhelper::Addons->new;
        $addons->load($self->data_paths, $self->vendor);

        return $addons;
    }
);

=item debhelper_commands

=cut

has debhelper_commands => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $commands = Lintian::Data::Debhelper::Commands->new;
        $commands->load($self->data_paths, $self->vendor);

        return $commands;
    }
);

=item debhelper_levels

=cut

has debhelper_levels => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $levels = Lintian::Data::Debhelper::Levels->new;
        $levels->load($self->data_paths, $self->vendor);

        return $levels;
    }
);

=item fonts

=cut

has fonts => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $fonts = Lintian::Data::Fonts->new;
        $fonts->load($self->data_paths, $self->vendor);

        return $fonts;
    }
);

=item hardening_buildflags

=cut

has hardening_buildflags => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $buildflags = Lintian::Data::Buildflags::Hardening->new;
        $buildflags->load($self->data_paths, $self->vendor);

        return $buildflags;
    }
);

=item mail_transport_agents

=cut

has mail_transport_agents => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Provides::MailTransportAgent->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    }
);

=item policy_releases

=cut

has policy_releases => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $releases = Lintian::Data::Policy::Releases->new;
        $releases->load($self->data_paths, $self->vendor);

        return $releases;
    }
);

=item sections

=cut

has sections => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $sections = Lintian::Data::Archive::Sections->new;
        $sections->load($self->data_paths, $self->vendor);

        return $sections;
    }
);

=item style_sheet

=cut

has style_sheet => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $releases = Lintian::Data::Stylesheet->new;
        $releases->load($self->data_paths, $self->vendor);

        return $releases;
    }
);

=item virtual_initd_facilities

=cut

has virtual_initd_facilities => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $facilities = Lintian::Data::InitD::VirtualFacilities->new;
        $facilities->load($self->data_paths, $self->vendor);

        return $facilities;
    }
);

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

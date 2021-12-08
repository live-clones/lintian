# Copyright © 2011 Niels Thykier <niels@thykier.net>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
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

package Lintian::Data;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Data::Architectures;
use Lintian::Data::Authority::DebconfSpecification;
use Lintian::Data::Authority::DebianPolicy;
use Lintian::Data::Authority::DeveloperReference;
use Lintian::Data::Authority::DocBaseManual;
use Lintian::Data::Authority::FilesystemHierarchy;
use Lintian::Data::Authority::JavaPolicy;
use Lintian::Data::Authority::LintianManual;
use Lintian::Data::Authority::MenuPolicy;
use Lintian::Data::Authority::MenuManual;
use Lintian::Data::Authority::PerlPolicy;
use Lintian::Data::Authority::PythonPolicy;
use Lintian::Data::Authority::VimPolicy;
use Lintian::Data::Debhelper::Addons;
use Lintian::Data::Debhelper::Commands;
use Lintian::Data::Debhelper::Levels;
use Lintian::Data::Fonts;
use Lintian::Data::Buildflags::Hardening;
use Lintian::Data::Policy::Releases;
use Lintian::Data::Stylesheet;
use Lintian::Data::Traditional;

const my $EMPTY => q{};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Data - Data parser for Lintian

=head1 SYNOPSIS

 my $profile = Lintian::Data->new ('debian');

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
    default => sub { [] });

has data_cache => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

=item load

=cut

sub load {
    my ($self, $location, $separator, $accumulator) = @_;

    croak encode_utf8('no data type specified')
      unless $location;

    unless (exists $self->data_cache->{$location}) {

        my $cache = Lintian::Data::Traditional->new;
        $cache->location($location);
        $cache->separator($separator);
        $cache->accumulator($accumulator);

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
        $self->architectures,$self->debconf_specification,
        $self->developer_reference,$self->debhelper_addons,
        $self->debhelper_commands,$self->doc_base_manual,
        $self->filesystem_hierarchy_standard,$self->fonts,
        $self->hardening_buildflags,$self->java_policy,
        $self->lintian_manual,$self->menu_policy,
        $self->menu_manual,$self->perl_policy,
        $self->policy_manual,$self->policy_releases,
        $self->python_policy,$self->style_sheet,
        $self->vim_policy
    );

    return @sources;
}

=item markdown_authority_reference

=cut

sub markdown_authority_reference {
    my ($self, $volume, $section) = @_;

    my @MARKDOWN_CAPABLE = (
        $self->menu_policy,$self->perl_policy,
        $self->python_policy,$self->java_policy,
        $self->vim_policy,$self->lintian_manual,
        $self->developer_reference,$self->policy_manual,
        $self->debconf_specification,$self->menu_manual,
        $self->doc_base_manual,$self->filesystem_hierarchy_standard,
    );

    my %by_shorthand = map { $_->shorthand => $_ } @MARKDOWN_CAPABLE;

    return $EMPTY
      unless exists $by_shorthand{$volume};

    my $manual = $by_shorthand{$volume};

    return $manual->markdown_citation($section);
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
    });

=item debconf_specification

=cut

has debconf_specification => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::DebconfSpecification->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

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
    });

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
    });

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
    });

=item developer_reference

=cut

has developer_reference => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::DeveloperReference->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

=item doc_base_manual

=cut

has doc_base_manual => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::DocBaseManual->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

=item filesystem_hierarchy_standard

=cut

has filesystem_hierarchy_standard => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual= Lintian::Data::Authority::FilesystemHierarchy->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

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
    });

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
    });

=item java_policy

=cut

has java_policy => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::JavaPolicy->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

=item lintian_manual

=cut

has lintian_manual => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::LintianManual->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

=item menu_manual

=cut

has menu_manual => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::MenuManual->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

=item menu_policy

=cut

has menu_policy => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::MenuPolicy->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

=item perl_policy

=cut

has perl_policy => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::PerlPolicy->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

=item policy_manual

=cut

has policy_manual => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::DebianPolicy->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

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
    });

=item python_policy

=cut

has python_policy => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::PythonPolicy->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

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
    });

=item vim_policy

=cut

has vim_policy => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::VimPolicy->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    });

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

# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
# Copyright (C) 2018 Chris Lamb <lamby@debian.org>
# Copyright (C) 2021 Felix Lechner
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

package Lintian::Data::Authorities;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Data::Authority::DebconfSpecification;
use Lintian::Data::Authority::DebianPolicy;
use Lintian::Data::Authority::DeveloperReference;
use Lintian::Data::Authority::DocBaseManual;
use Lintian::Data::Authority::FilesystemHierarchy;
use Lintian::Data::Authority::JavaPolicy;
use Lintian::Data::Authority::LintianManual;
use Lintian::Data::Authority::MenuPolicy;
use Lintian::Data::Authority::MenuManual;
use Lintian::Data::Authority::NewMaintainer;
use Lintian::Data::Authority::PerlPolicy;
use Lintian::Data::Authority::PythonPolicy;
use Lintian::Data::Authority::VimPolicy;

const my $EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Data::Authorities - Lintian's Reference Authorities

=head1 SYNOPSIS

 my $data = Lintian::Data->new;

=head1 DESCRIPTION

Lintian::Data::Authorities handles finding, parsing and implementation of Lintian reference authorities

=head1 INSTANCE METHODS

=over 4

=item markdown_authority_reference

=cut

sub markdown_authority_reference {
    my ($self, $volume, $section) = @_;

    my @MARKDOWN_CAPABLE = (
        $self->new_maintainer,$self->menu_policy,
        $self->perl_policy,$self->python_policy,
        $self->java_policy,$self->vim_policy,
        $self->lintian_manual,$self->developer_reference,
        $self->policy_manual,$self->debconf_specification,
        $self->menu_manual,$self->doc_base_manual,
        $self->filesystem_hierarchy_standard,
    );

    my %by_shorthand = map { $_->shorthand => $_ } @MARKDOWN_CAPABLE;

    return $EMPTY
      unless exists $by_shorthand{$volume};

    my $manual = $by_shorthand{$volume};

    return $manual->markdown_citation($section);
}

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
    }
);

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
    }
);

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
    }
);

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
    }
);

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
    }
);

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
    }
);

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
    }
);

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
    }
);

=item menu_policy

=cut

has new_maintainer => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $manual = Lintian::Data::Authority::NewMaintainer->new;
        $manual->load($self->data_paths, $self->vendor);

        return $manual;
    }
);

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
    }
);

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
    }
);

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
    }
);

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
    }
);

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

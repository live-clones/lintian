# -*- perl -*-
#
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

package Lintian::Data::Archive::AutoRejection;

use v5.20;
use warnings;
use utf8;

use Carp qw(carp);
use Const::Fast;
use HTTP::Tiny;
use List::SomeUtils qw(first_value uniq);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);
use YAML::XS qw(LoadFile);

const my $EMPTY => q{};
const my $SLASH => q{/};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Data::Archive::AutoRejection - Lintian interface to the archive's auto-rejection tags

=head1 SYNOPSIS

    use Lintian::Data::Archive::AutoRejection;

=head1 DESCRIPTION

This module provides a way to load data files for the archive's auto-rejection tags

=head1 INSTANCE METHODS

=over 4

=item title

=item location

=item certain

=item preventable

=cut

has title => (
    is => 'rw',
    default => 'Archive Auto-Rejection Tags'
);

has location => (
    is => 'rw',
    default => 'archive/auto-rejection.yaml'
);

has certain => (is => 'rw', default => sub { [] });
has preventable => (is => 'rw', default => sub { [] });

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    unless (length $path) {
        carp encode_utf8('Unknown data file: ' . $self->location);
        return;
    }

    my $yaml = LoadFile($path);
    die encode_utf8('Could not parse YAML file ' . $self->location)
      unless defined $yaml;

    my $base = $yaml->{lintian};
    die encode_utf8('Could not parse document base for ' . $self->location)
      unless defined $base;

    my @certain = uniq @{ $base->{fatal} // [] };
    my @preventable = uniq @{ $base->{nonfatal} // [] };

    $self->certain(\@certain);
    $self->preventable(\@preventable);

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    my $auto_rejection_url
      = 'https://ftp-master.debian.org/static/lintian.tags';

    my $response = HTTP::Tiny->new->get($auto_rejection_url);
    die encode_utf8("Failed to get $auto_rejection_url!\n")
      unless $response->{success};

    my $auto_rejection_yaml = $response->{content};

    my $data_path = "$basedir/" . $self->location;
    my $parent_dir = path($data_path)->parent->stringify;
    path($parent_dir)->mkpath
      unless -e $parent_dir;

    # already in UTF-8
    path($data_path)->spew($auto_rejection_yaml);

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

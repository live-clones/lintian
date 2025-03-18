# -*- perl -*-
#
# Copyright (C) 2021 Felix Lechner
# Copyright (C) 2022 Axel Beckert
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

package Lintian::Data::Archive::Sections;

use v5.20;
use warnings;
use utf8;

use Carp qw(carp);
use Const::Fast;
use HTTP::Tiny;
use List::SomeUtils qw(first_value uniq);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);
use Lintian::Deb822;

const my $EMPTY => q{};
const my $SLASH => q{/};

use Moo;
use namespace::clean;

with 'Lintian::Data::JoinedLines';

=head1 NAME

Lintian::Data::Archive::Sections - Lintian interface to the archive's sections

=head1 SYNOPSIS

    use Lintian::Data::Archive::Sections;

=head1 DESCRIPTION

This module provides a way to load the data file for the archive's section.

=head1 INSTANCE METHODS

=over 4

=item title

=cut

has title => (
    is => 'rw',
    default => 'Archive Sections'
);

=item location

=cut

has location => (
    is => 'rw',
    default => 'fields/archive-sections'
);

=item separator

=cut

has separator => (is => 'rw');

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    my $sections_url = 'https://metadata.ftp-master.debian.org/sections.822';

    my $response = HTTP::Tiny->new->get($sections_url);
    die encode_utf8("Failed to get $sections_url!\n")
      unless $response->{success};

    my $sections_822 = $response->{content};

    # TODO: We should probably save this in the original format and
    # parse it with Lintian::Deb822 at some time.
    my $sections = join("\n",
        map { s/^Section: //r }
          grep { m{^Section: [^/]*$} }
          split(/\n/, $sections_822))."\n";

    my $data_path = "$basedir/" . $self->location;
    my $parent_dir = path($data_path)->parent->stringify;
    path($parent_dir)->mkpath
      unless -e $parent_dir;

    # already in UTF-8
    path($data_path)->spew($sections);

    return 1;
}

=back

=head1 AUTHOR

Originally written by Axel Beckert <abe@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

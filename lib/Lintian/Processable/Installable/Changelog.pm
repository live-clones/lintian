# -*- perl -*- Lintian::Processable::Installable::Changelog -- access to collected changelog data
#
# Copyright © 1998 Richard Braakman
# Copyright © 2019-2021 Felix Lechner
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

package Lintian::Processable::Installable::Changelog;

use v5.20;
use warnings;
use utf8;

use File::Copy qw(copy);
use List::SomeUtils qw(first_value);
use Path::Tiny;
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Installable::Changelog - access to collected changelog data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Installable::Changelog provides an interface to changelog data.

=head1 INSTANCE METHODS

=over 4

=item changelog_item

=cut

has changelog_item => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @candidate_names = (
            'changelog.Debian.gz','changelog.Debian',
            'changelog.debian.gz','changelog.debian',
            'changelog.gz','changelog',
        );

        my $package_path = 'usr/share/doc/' . $self->name;
        my @candidate_items = grep { defined }
          map { $self->installed->lookup("$package_path/$_") }@candidate_names;

        # pick the first existing file
        my $item
          = first_value { $_->is_file || length $_->link } @candidate_items;

        return $item;
    });

=item changelog

For binary:

Returns the changelog of the binary package as a Parse::DebianChangelog
object, or an empty object if the changelog doesn't exist.  The changelog-file
collection script must have been run to create the changelog file, which
this method expects to find in F<changelog>.

=cut

has changelog => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $changelog = Lintian::Changelog->new;

        my $unresolved = $self->changelog_item;

        # stop for dangling symbolic link
        my $item = $unresolved->resolve_path;
        return $changelog
          unless defined $item;

        # return empty changelog
        return $changelog
          unless $item->is_file && $item->is_open_ok;

        if ($item->basename =~ m{ [.]gz $}x) {

            my $bytes = safe_qx('gunzip', '-c', $item->unpacked_path);

            return $changelog
              unless valid_utf8($bytes);

            $changelog->parse(decode_utf8($bytes));

            return $changelog;
        }

        return $changelog
          unless $item->is_valid_utf8;

        $changelog->parse($item->decoded_utf8);

        return $changelog;
    });

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

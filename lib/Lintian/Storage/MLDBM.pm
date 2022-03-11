# -*- perl -*- Lintian::Storage::MLDBM
#
# Copyright © 2022 Felix Lechner
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

package Lintian::Storage::MLDBM;

use v5.20;
use warnings;
use utf8;

use BerkeleyDB;
use Const::Fast;
use MLDBM qw(BerkeleyDB::Btree Storable);
use Path::Tiny;
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

const my $EMPTY => q{};
const my $HYPHEN => q{-};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Storage::MLDBM - store multi-level hashes on disk

=head1 SYNOPSIS

    use Lintian::Storage::MLDBM;

=head1 DESCRIPTION

Lintian::Storage::MLDBM provides an interface to store data on disk to preserve memory.

=head1 INSTANCE METHODS

=over 4

=item tied_hash

=cut

has tied_hash => (is => 'rw', default => sub { {} });

=item create

=cut

sub create {
    my ($self, $description) = @_;

    $description //= $EMPTY;

    $description .= $HYPHEN
      if length $description;

    my $stem = "mldbm-$description";

    # deleted once the last reference is lost
    my $tempfile= Path::Tiny->tempfile(TEMPLATE => $stem . 'XXXXXXXX',);

    try {
        tie(
            %{$self->tied_hash}, 'MLDBM',
            -Filename => $tempfile->stringify,
            -Flags    => DB_CREATE
        );

    } catch {
        die encode_utf8("Cannot create database in $tempfile: $@");
    };

    return;
}

=item DEMOLISH

=cut

sub DEMOLISH {
    my ($self, $in_global_destruction) = @_;

    untie %{$self->tied_hash};

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

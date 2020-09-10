# -*- perl -*- Lintian::Index::Orig
#
# Copyright © 2020 Felix Lechner
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

package Lintian::Index::Orig;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(uniq);
use List::UtilsBy qw(sort_by);
use Path::Tiny;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};

use Moo;
use namespace::clean;

with 'Lintian::Index';

=encoding utf-8

=head1 NAME

Lintian::Index::Orig -- An index of an upstream (orig) file set

=head1 SYNOPSIS

 use Lintian::Index::Orig;

 # Instantiate via Lintian::Index::Orig
 my $orig = Lintian::Index::Orig->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
upstream file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4

=item collect

=item create

=cut

my %DECOMPRESS_COMMAND = (
    'gz' => 'gzip --decompress --stdout',
    'bz2' => 'bzip2 --decompress --stdout',
    'xz' => 'xz --decompress --stdout',
);

sub collect {
    my ($self, $processable_dir, $components) = @_;

    # source packages can be unpacked anywhere; no anchored roots
    $self->allow_empty(1);

    my $combined_errors = EMPTY;

    # keep sort order; root is missing below otherwise
    my @tarballs = sort_by { $components->{$_} } keys %{$components};

    for my $tarball (@tarballs) {

        my $component = $components->{$tarball};

        # so far, all archives with components had an extra level
        my $component_dir = $self->basedir;

        my $subindex = Lintian::Index::Orig->new;
        $subindex->basedir($component_dir);

        # source packages can be unpacked anywhere; no anchored roots
        $subindex->allow_empty(1);

        my ($extension) = ($tarball =~ /\.([^.]+)$/);
        die "Source component $tarball has no file exension\n"
          unless length $extension;

        my $decompress = $DECOMPRESS_COMMAND{lc $extension};
        die "Don't know how to decompress $tarball"
          unless $decompress;

        my @command = (split(SPACE, $decompress), "$processable_dir/$tarball");

        my ($extract_errors, $index_errors)
          = $subindex->create_from_piped_tar(\@command);

        $combined_errors .= $extract_errors . $index_errors;

        # treat hard links like regular files
        for my $item (values %{$subindex->catalog}) {

            my $perm = $item->perm;
            $perm =~ s/^h/-/;
            $item->perm($perm);
        }

        # removes root entry (''); do not use sorted_list
        my @prefixes = grep { length } %{$subindex->catalog};

        # keep top level prefixes
        s{^([^/]+).*$}{$1}s for @prefixes;

        # squash identical values
        my @unique = uniq @prefixes;

        # unwanted top-level common prefix
        my $unwanted = EMPTY;

        # check for a single common value
        if (@unique == 1) {
            my $common = $unique[0];

            my $conflict = $subindex->lookup($common);

            # use only if there is no directory with that name
            $unwanted = $common
              unless defined $conflict && $conflict->perm =~ /^d/;
        }

        # inserts missing directories; must occur afterwards
        $subindex->load;

        # keep common prefix when equal to the source component
        unless ($unwanted eq $component) {
            $subindex->drop_common_prefix;
            $subindex->drop_basedir_segment;
        }

        $self->merge_in($subindex);
    }

    return $combined_errors;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.
Substantial portions adapted from code written by Russ Allbery, Niels Thykier, and others.

=head1 SEE ALSO

lintian(1)

L<Lintian::Index>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

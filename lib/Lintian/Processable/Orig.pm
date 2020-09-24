# -*- perl -*- Lintian::Processable::Orig
#
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

package Lintian::Processable::Orig;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(uniq);
use List::UtilsBy qw(sort_by);
use Path::Tiny;

use Lintian::Index;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Orig - access to collected data about the upstream (orig) sources

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Orig provides an interface to collected data about the upstream (orig) sources.

=head1 INSTANCE METHODS

=over 4

=item orig

Returns the index for orig.tar.gz.

=cut

my %DECOMPRESS_COMMAND = (
    'gz' => 'gzip --decompress --stdout',
    'bz2' => 'bzip2 --decompress --stdout',
    'xz' => 'xz --decompress --stdout',
);

has orig => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $index = Lintian::Index->new;
        $index->basedir($self->basedir . SLASH . 'orig');

        return $index
          if $self->native;

        # source packages can be unpacked anywhere; no anchored roots
        $index->allow_empty(1);

        my $combined_errors = EMPTY;

        # keep sort order; root is missing below otherwise
        my @tarballs
          = sort_by { $self->components->{$_} } keys %{$self->components};

        for my $tarball (@tarballs) {

            my $component = $self->components->{$tarball};

            # so far, all archives with components had an extra level
            my $component_dir = $index->basedir;

            my $subindex = Lintian::Index->new;
            $subindex->basedir($component_dir);

            # source packages can be unpacked anywhere; no anchored roots
            $subindex->allow_empty(1);

            my ($extension) = ($tarball =~ /\.([^.]+)$/);
            die "Source component $tarball has no file exension\n"
              unless length $extension;

            my $decompress = $DECOMPRESS_COMMAND{lc $extension};
            die "Don't know how to decompress $tarball"
              unless $decompress;

            my @command
              = (split(SPACE, $decompress), $self->basedir . SLASH . $tarball);

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
            my @prefixes = grep { m{/} } %{$subindex->catalog};

            # keep top level prefixes
            s{^([^/]+)/.*$}{$1}s for @prefixes;

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
            if ($unwanted ne $component) {
                $subindex->drop_common_prefix;
                $subindex->drop_basedir_segment;
            }

            $index->merge_in($subindex);

            $self->tag('unpack-message-for-orig', $_)
              for split(/\n/, $combined_errors);
        }

        return $index;
    });

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

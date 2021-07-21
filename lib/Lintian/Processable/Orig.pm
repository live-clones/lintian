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

use Const::Fast;
use List::SomeUtils qw(uniq);
use List::UtilsBy qw(sort_by);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Index;

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};

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
        $index->basedir($self->basedir . $SLASH . 'orig');

        return $index
          if $self->native;

        # source packages can be unpacked anywhere; no anchored roots
        $index->anchored(0);

        my %components = %{$self->components};

        # keep sort order; root is missing below otherwise
        my @tarballs = sort_by { $components{$_} } keys %components;

        for my $tarball (@tarballs) {

            my $component = $components{$tarball};

            # so far, all archives with components had an extra level
            my $component_dir = $index->basedir;
            $component_dir .= $SLASH . $component
              if length $component;

            my $subindex = Lintian::Index->new;
            $subindex->basedir($component_dir);

            # source packages can be unpacked anywhere; no anchored roots
            $index->anchored(0);

            my ($extension) = ($tarball =~ /\.([^.]+)$/);
            die encode_utf8("Source component $tarball has no file exension\n")
              unless length $extension;

            my $decompress = $DECOMPRESS_COMMAND{lc $extension};
            die encode_utf8("Don't know how to decompress $tarball")
              unless $decompress;

            my @command
              = (split($SPACE, $decompress),
                $self->basedir . $SLASH . $tarball);

            my $errors = $subindex->create_from_piped_tar(\@command);

            $self->hint('unpack-message-for-orig', $tarball, $_)
              for uniq split(/\n/, $errors);

            # treat hard links like regular files
            my @hardlinks = grep { $_->is_hardlink } @{$subindex->sorted_list};
            for my $item (@hardlinks) {

                my $target = $subindex->lookup($item->link);

                $item->unpacked_path($target->unpacked_path);
                $item->size($target->size);
                $item->link($EMPTY);

                # turn into a regular file
                my $perm = $item->perm;
                $perm =~ s/^-/h/;
                $item->perm($perm);

                $item->path_info(
                    ($item->path_info & ~Lintian::Index::Item::TYPE_HARDLINK)
                    | Lintian::Index::Item::TYPE_FILE);
            }

            my @prefixes = @{$subindex->sorted_list};

            # keep top level prefixes; no trailing slashes
            s{^([^/]+).*$}{$1}s for @prefixes;

            # squash identical values; ignore root entry ('')
            my @unique = grep { length } uniq @prefixes;

            # check for single common value
            if (@unique == 1) {

                # no trailing slash for directories
                my $common = $unique[0];

                # proceed if no file with that name (lacks slash)
                my $conflict = $subindex->lookup($common);
                unless (defined $conflict) {

                    if ($common ne $component || length $component) {

                        # shortens paths; keeps same base directory
                        my $sub_errors = $subindex->drop_common_prefix;

                        $self->hint('unpack-message-for-orig', $tarball, $_)
                          for uniq split(/\n/, $sub_errors);
                    }
                }
            }

            # lowers base directory to match index being merged into
            $subindex->capture_common_prefix
              if length $component;

            $index->merge_in($subindex);
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

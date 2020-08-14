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

sub collect {
    my ($self, $groupdir, $components) = @_;

    # source packages can be unpacked anywhere; no anchored roots
    $self->allow_empty(1);

    my $basedir = path($groupdir)->child('orig')->stringify;
    $self->basedir($basedir);

    $self->create($groupdir, $components);
    $self->load;

    return;
}

my %DECOMPRESS_COMMAND = (
    'gz' => 'gzip --decompress --stdout',
    'bz2' => 'bzip2 --decompress --stdout',
    'xz' => 'xz --decompress --stdout',
);

sub create {
    my ($self, $groupdir, $components) = @_;

    my %all;
    for my $tarball (sort keys %{$components}) {

        my $component = $components->{$tarball};

        my ($extension) = ($tarball =~ /\.([^.]+)$/);
        die "Source component $tarball has no file exension\n"
          unless length $extension;

        my $decompress = $DECOMPRESS_COMMAND{lc $extension};
        die "Don't know how to decompress $tarball"
          unless $decompress;

        my @command = (split(SPACE, $decompress), "$groupdir/$tarball");

        my ($extract_errors, $index_errors)
          = $self->create_from_piped_tar(\@command, $component);

        path("$groupdir/orig-index-errors")->append($index_errors)
          if length $index_errors;

        # produce composite index for multiple components
        my %single = %{$self->catalog};
        $self->catalog({});

        # remove base directory from output
        delete $single{''}
          if exists $single{''};

        # unwanted top-level common prefix
        my $unwanted = EMPTY;

        # find all top-level prefixes
        my @prefixes = keys %single;
        s{^([^/]+).*$}{$1}s for @prefixes;

        # squash identical values
        my @unique = uniq @prefixes;

        # check for a single common value
        if (@unique == 1) {
            my $common = $unique[0];

            # use only if there is no directory with that name
            $unwanted = $common
              unless $single{$common} && $single{$common}->perm =~ /^d/;
        }

        # keep common prefix when equal to the source component
        unless ($unwanted eq $component) {

            my %copy;
            for my $name (keys %single) {

                my $adjusted = $name;

                # strip common prefix
                $adjusted =~ s{^\Q$unwanted\E/+}{}
                  if length $unwanted;

                # add component name
                $adjusted = $component . SLASH . $adjusted
                  if length $component;

                # change name of entry
                $single{$name}->name($adjusted);

                # store entry under new name
                $copy{$adjusted} = $single{$name};
            }

            %single = %copy;
        }

        $all{$_} = $single{$_} for keys %single;
    }

    # treat hard links like regular files
    for my $name (keys %all) {
        my $perm = $all{$name}->perm;
        $perm =~ s/^h/-/;
        $all{$name}->perm($perm);
    }

    $self->catalog(\%all);

    return;
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

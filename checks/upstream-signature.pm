# upstream-signature -- lintian check script -*- perl -*-
#
# Copyright © 2019 Felix Lechner
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

package Lintian::upstream_signature;

use strict;
use warnings;

use Path::Tiny;
use List::Util qw(none);

use constant SLASH => q{/};

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $SIGNING_KEY_FILENAMES = Lintian::Data->new('common/signing-key-filenames');

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my @keynames = $SIGNING_KEY_FILENAMES->all;
    my @keypaths
      = map { $processable->patched->resolve_path("debian/$_") } @keynames;
    my @keys = grep { $_ && $_->is_file } @keypaths;

    # in uscan's gittag mode,signature will never match
    my $watch = $processable->patched->resolve_path('debian/watch');
    my $gittag = $watch && $watch->slurp =~ m/pgpmode=gittag/;

    my @filenames = sort keys %{$processable->files};
    my @origtar
      = grep {$_ =~ m/^.*\.orig(?:-[A-Za-z\d-]+)?\.tar\./&& $_ !~ m/\.asc$/}
      @filenames;

    my %signatures;
    for my $filename (@origtar) {

        my ($uncompressed) = ($filename =~ /(^.*\.tar)/);

        my @componentsigs;
        for my $tarball ($filename, $uncompressed) {
            my $signaturename = "$tarball.asc";
            push(@componentsigs, $signaturename)
              if exists $processable->files->{$signaturename};
        }

        $signatures{$filename} = \@componentsigs;
    }

    # orig tarballs should be signed if upstream's public key is present
    unless (!@keys || $processable->repacked || $gittag) {

        for my $filename (@origtar) {

            $self->tag('orig-tarball-missing-upstream-signature', $filename)
              unless scalar @{$signatures{$filename}};
        }
    }

    # check signatures
    my @allsigs = map { @{$signatures{$_}} } @origtar;
    for my $signature (@allsigs) {

        my $path = $processable->groupdir . SLASH . $signature;
        my $contents = path($path)->slurp;

        if ($contents =~ /^-----BEGIN PGP ARMORED FILE-----/m) {

            if ($contents =~ /^LS0tLS1CRUd/m) {
                # doubly armored
                $self->tag('doubly-armored-upstream-signature', $signature);

            } else {
                # non standard armored header
                $self->tag('explicitly-armored-upstream-signature',$signature);
            }

            my @spurious = ($contents =~ /\n([^:\n]+):/g);
            $self->tag('spurious-fields-in-upstream-signature',
                $signature, @spurious)
              if @spurious;
        }

        # multiple signatures in one file
        $self->tag('concatenated-upstream-signatures', $signature)
          if $contents
          =~ m/(?:-----BEGIN PGP SIGNATURE-----[^-]*-----END PGP SIGNATURE-----\s*){2,}/;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

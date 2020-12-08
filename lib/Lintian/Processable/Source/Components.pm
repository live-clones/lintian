# -*- perl -*-
# Lintian::Processable::Source::Components -- interface to orig tag components
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

package Lintian::Processable::Source::Components;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};

=head1 NAME

Lintian::Processable::Source::Components - interface to orig tar components

=head1 SYNOPSIS

   use Moo;

   with 'Lintian::Processable::Source::Components';

=head1 DESCRIPTION

Lintian::Processable::Source::Components provides an interface to data for
upstream source components. Most sources only use one tarball.

=head1 INSTANCE METHODS

=over 4

=item components

Returns a reference to a hash containing information about source components
listed in the .dsc file.  The key is the filename, and the value is the name
of the component.

=cut

has components => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # determine source and version; handle missing fields
        my $name = $self->fields->value('Source');
        my $version = $self->fields->value('Version');
        my $architecture = 'source';

        # it is its own source package
        my $source = $name;
        my $source_version = $version;

        # version handling based on Dpkg::Version::parseversion.
        my $noepoch = $source_version;
        if ($noepoch =~ /:/) {
            $noepoch =~ s/^(?:\d+):(.+)/$1/
              or die encode_utf8("Bad version number '$noepoch'");
        }

        my $baserev = $source . '_' . $noepoch;

        # strip debian revision
        $noepoch =~ s/(.+)-(?:.*)$/$1/;
        my $base = $source . '_' . $noepoch;

        my $files = $self->files;

        my %components;
        for my $name (keys %{$files}) {

            # Look for $pkg_$version.orig(-$comp)?.tar.$ext (non-native)
            #       or $pkg_$version.tar.$ext (native)
            #  - This deliberately does not look for the debian packaging
            #    even when this would be a tarball.
            if ($name
                =~ /^(?:\Q$base\E\.orig(?:-(.*))?|\Q$baserev\E)\.tar\.(?:gz|bz2|lzma|xz)$/
            ) {
                $components{$name} = $1 // $EMPTY;
            }
        }

        return \%components;
    });

=back

=head1 AUTHOR

Originally written by Adam D. Barratt <adsb@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Processable>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

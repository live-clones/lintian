# -*- perl -*-
# Lintian::Info::Fields::Files -- interface to .buildinfo file data collection
#
# Copyright © 2010 Adam D. Barratt
# Copyright © 2018 Chris Lamb
# Copyright © 2019 Felix Lechner
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

package Lintian::Info::Fields::Files;

use strict;
use warnings;

use Lintian::Util qw(strip);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Info::Fields::Files - Lintian interface to .buildinfo or changes file data collection

=head1 SYNOPSIS

   use Moo;

   with 'Lintian::Info::Fields::Files';

=head1 DESCRIPTION

Lintian::Info::Fields::Files provides an interface to data for .buildinfo
and changes files.  It implements data collection methods specific to .buildinfo
and changes files.

=head1 INSTANCE METHODS

In addition to the instance methods listed below, all instance methods
documented in the L<Lintian::Collect> module are also available.

=over 4

=item files

Returns a reference to a hash containing information about files listed
in the .buildinfo file.  Each hash may have the following keys:

=over 4

=item name

Name of the file.

=item size

The size of the file in bytes.

=item section

The archive section to which the file belongs.

=item priority

The priority of the file.

=item checksums

A hash with the keys being checksum algorithms and the values themselves being
hashes containing

=over 4

=item sum

The result of applying the given algorithm to the file.

=item filesize

The size of the file as given in the .buildinfo section relating to the given
checksum.

=back

=back

Needs-Info requirements for using I<files>: L<Lintian::Collect/field ([FIELD[, DEFAULT]])>

=item saved_files

=cut

has saved_files => (is => 'rwp', default => sub { {} });

sub files {
    my ($self) = @_;

    return $self->saved_files
      if scalar keys %{$self->saved_files};

    my %files;

    my $file_list = $self->field('files') || '';

    local $_;

    for (split /\n/, $file_list) {
        strip;
        next if $_ eq '';

        my ($md5sum,$size,$section,$priority,$file) = split(/\s+/o, $_);

        next
          if $file =~ m,/,;

        $files{$file}{checksums}{md5} = {
            'sum' => $md5sum,
            'filesize' => $size,
        };
        $files{$file}{name} = $file;
        $files{$file}{size} = $size;
        $files{$file}{section} = $section;
        $files{$file}{priority} = $priority;
    }

    foreach my $alg (qw(sha1 sha256)) {

        my $list = $self->field("checksums-$alg") || '';

        for (split /\n/, $list) {
            strip;
            next if $_ eq '';

            my ($checksum, $size, $file) = split(/\s+/o, $_);
            next if $file =~ m,/,;

            $files{$file}{checksums}{$alg} = {
                'sum' => $checksum,
                'filesize' => $size
            };
        }
    }

    $self->_set_saved_files(\%files);

    return $self->saved_files;
}

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

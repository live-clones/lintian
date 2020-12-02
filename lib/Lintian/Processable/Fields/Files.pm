# -*- perl -*-
# Lintian::Processable::Fields::Files -- interface to .buildinfo file data collection
#
# Copyright © 2010 Adam D. Barratt
# Copyright © 2018 Chris Lamb
# Copyright © 2019-2020 Felix Lechner
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

package Lintian::Processable::Fields::Files;

use v5.20;
use warnings;
use utf8;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Fields::Files - Lintian interface to .buildinfo or changes file data collection

=head1 SYNOPSIS

   use Moo;

   with 'Lintian::Processable::Fields::Files';

=head1 DESCRIPTION

Lintian::Processable::Fields::Files provides an interface to data for .buildinfo
and changes files.  It implements data collection methods specific to .buildinfo
and changes files.

=head1 INSTANCE METHODS

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

=cut

has files => (
    is => 'rw',
    lazy => 1,
    default =>

      sub {
        my ($self) = @_;

        my %files;

        my @files_lines = split(/\n/, $self->fields->value('Files'));

        # trim both ends of each line
        s/^\s+|\s+$//g for @files_lines;

        for my $line (grep { length } @files_lines) {

            my @fields = split(/\s+/, $line);
            my $basename = $fields[-1];

            # ignore traversals
            next
              if $basename =~ m{/};

            my ($md5sum, $size, $section, $priority) = @fields;

            $files{$basename}{checksums}{Md5} = {
                'sum' => $md5sum,
                'filesize' => $size,
            };

            $files{$basename}{name} = $basename;
            $files{$basename}{size} = $size;

            unless ($self->type eq 'source') {

                $files{$basename}{section} = $section;
                $files{$basename}{priority} = $priority;
            }
        }

        for my $algorithm (qw(Sha1 Sha256)) {

            my @lines
              = split(/\n/, $self->fields->value("Checksums-$algorithm"));

            # trim both ends of each line
            s/^\s+|\s+$//g for @lines;

            for my $line (grep { length } @lines) {

                my ($checksum, $size, $basename) = split(/\s+/, $line);

                # ignore traversals
                next
                  if $basename =~ m{/};

                $files{$basename}{checksums}{$algorithm} = {
                    'sum' => $checksum,
                    'filesize' => $size
                };
            }
        }

        return \%files;
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

# -*- perl -*- Lintian::Info::FileInfo -- access to collected file-info data
#
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

package Lintian::Info::FileInfo;

use strict;
use warnings;
use autodie;

use BerkeleyDB;
use Path::Tiny;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Info::FileInfo - access to collected file-info data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Info::FileInfo provides an interface to package data for
file(1) information, aka magic data.

=head1 INSTANCE METHODS

=over 4

=item file_info (FILE)

Returns the output of file(1) for FILE (if it exists) or C<undef>.

NB: The value may have been calibrated by Lintian.  A notorious example
is gzip files, where file(1) can be unreliable at times (see #620289)

Needs-Info requirements for using I<file_info>: file-info

=cut

has saved_file_info => (is => 'rwp');

sub file_info {
    my ($self, $path) = @_;

    unless ($self->saved_file_info) {

        my $dbpath = path($self->groupdir)->child('file-info.db')->stringify;

        my %file_info;

        tie my %h, 'BerkeleyDB::Btree',-Filename => $dbpath
          or die "Cannot open file $dbpath: $! $BerkeleyDB::Error\n";

        $file_info{$_} = $h{$_} for keys %h;

        untie %h;

        $self->_set_saved_file_info(\%file_info);
    }

    return $self->saved_file_info->{$path};
}

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

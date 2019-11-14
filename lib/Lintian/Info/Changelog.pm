# -*- perl -*- Lintian::Info::Changelog -- access to collected changelog data
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

package Lintian::Info::Changelog;

use strict;
use warnings;
use autodie;

use Path::Tiny;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Info::Changelog - access to collected changelog data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Info::Changelog provides an interface to changelog data.

=head1 INSTANCE METHODS

=over 4

=item changelog

For binary:

Returns the changelog of the binary package as a Parse::DebianChangelog
object, or undef if the changelog doesn't exist.  The changelog-file
collection script must have been run to create the changelog file, which
this method expects to find in F<changelog>.

Needs-Info requirements for using I<changelog>: changelog-file

For source:

Returns the changelog of the source package as a Parse::DebianChangelog
object, or C<undef> if the changelog cannot be resolved safely.

Needs-Info requirements for using I<changelog>: L<Same as index_resolved_path|Lintian::Info::Package/index_resolved_path(PATH)>

=item saved_changelog

Returns the cached changelog information.

=cut

has saved_changelog => (is => 'rw');

sub changelog {
    my ($self) = @_;

    return $self->saved_changelog
      if defined $self->saved_changelog;

    my $dch;

    if ($self->type eq 'source') {
        my $file = $self->index_resolved_path('debian/changelog');

        return
          unless $file && $file->is_open_ok;

        $dch = $file->fs_path;

    } else {
        $dch = path($self->groupdir)->child('changelog')->stringify;

        return
          unless -f $dch && !-l $dch;
    }

    my ($checksum, $changelog);

    my $shared = $self->{'_shared_storage'};
    if (defined $shared) {

        $checksum = get_file_checksum('sha1', $dch);
        $changelog = $shared->{'changelog'}{$checksum};
    }

    unless ($changelog) {
        my $contents = path($dch)->slurp;
        $changelog = Lintian::Inspect::Changelog->new;
        $changelog->parse($contents);

        $shared->{'changelog'}{$checksum} = $changelog
          if defined $shared;
    }

    $self->saved_changelog($changelog);

    return $self->saved_changelog;
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

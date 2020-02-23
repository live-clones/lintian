# -*- perl -*- Lintian::Info::Scripts::Control -- access to control script data
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

package Lintian::Info::Scripts::Control;

use strict;
use warnings;
use autodie;

use BerkeleyDB;
use MLDBM qw(BerkeleyDB::Btree Storable);
use Path::Tiny;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Info::Scripts::Control - access to control script data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Info::Scripts::Control provides an interface to package
data for control scripts.

=head1 INSTANCE METHODS

=over 4

=item control_scripts

Returns a hashref mapping a FILE to data about how it is run.

Needs-Info requirements for using I<control_scripts>: scripts

=item saved_control_scripts

Returns the cached control scripts.

=cut

has saved_control_scripts => (is => 'rwp', default => sub { {} });

sub control_scripts {
    my ($self) = @_;

    unless (keys %{$self->saved_control_scripts}) {

        my $dbpath
          = path($self->groupdir)->child('control-scripts.db')->stringify;

        my %control;

        tie my %h, 'BerkeleyDB::Btree',-Filename => $dbpath
          or die "Cannot open file $dbpath: $! $BerkeleyDB::Error\n";

        $control{$_} = $h{$_} for keys %h;

        untie %h;

        $self->_set_saved_control_scripts(\%control);
    }

    return $self->saved_control_scripts;
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

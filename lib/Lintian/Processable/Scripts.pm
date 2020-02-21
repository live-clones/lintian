# -*- perl -*- Lintian::Processable::Scripts -- access to collected scripts data
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

package Lintian::Processable::Scripts;

use strict;
use warnings;
use autodie;

use BerkeleyDB;
use MLDBM qw(BerkeleyDB::Btree Storable);
use Path::Tiny;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Scripts - access to collected scripts data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Scripts provides an interface to script data for packages.

=head1 INSTANCE METHODS

=over 4

=item scripts

Returns a hashref mapping a FILE to its script/interpreter information
(if FILE is a script).  If FILE is not a script, it is not in the hash
(and callers should use exists to test membership to ensure this
invariant holds).

The value for a given FILE consists of a table with the following keys
(and associated value):

=over 4

=item calls_env

Returns a truth value if the script uses env (/usr/bin/env or
/bin/env) in the "#!".  Otherwise it is C<undef>.

=item interpreter

This is the interpreter used.  If calls_env is true, this will be the
first argument to env.  Otherwise it will be the command listed after
the "#!".

NB: Some template files have "#!" lines like "#!@PERL@" or "#!perl".
In this case, this value will be @PERL@ or perl (respectively).

=item name

Return the file name of the script.  This will be identical to key to
look up this table.

=back

Needs-Info requirements for using I<scripts>: scripts

=item saved_scripts

Returns the cached scripts information.

=cut

has saved_scripts => (is => 'rw', default => sub { {} });

sub scripts {
    my ($self) = @_;

    unless (keys %{$self->saved_scripts}) {

        my %scripts;

        my $dbpath = path($self->groupdir)->child('scripts.db')->stringify;

        tie my %h, 'MLDBM',-Filename => $dbpath
          or die "Cannot open file $dbpath: $! $BerkeleyDB::Error\n";

        $scripts{$_} = $h{$_} for keys %h;

        untie %h;

        $self->saved_scripts(\%scripts);
    }

    return $self->saved_scripts;
}

=item is_script (PATH)

True if PATH is a script.

Needs-Info requirements for using I<is_script>: scripts

=cut

sub is_script {
    my ($self, $path) = @_;

    return 0
      unless length $path;

    return 1
      if exists $self->scripts->{$path};

    return 0;
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

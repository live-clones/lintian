# -*- perl -*- Lintian::Processable::Installable::Conffiles
#
# Copyright (C) 2019 Felix Lechner
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

package Lintian::Conffiles;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Conffiles::Entry;

const my $SPACE => q{ };
const my $NEWLINE => qq{\n};

const my $TRUE => 1;
const my $FALSE => 0;

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Conffiles - access to collected control data for conffiles

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Conffiles provides an interface to control data for conffiles.

=head1 INSTANCE METHODS

=over 4

=item by_file

=cut

has by_file => (is => 'rw', default => sub { {} });

=item parse

=cut

sub parse {
    my ($self, $item) = @_;

    return
      unless $item && $item->is_valid_utf8;

    my @lines = split($NEWLINE, $item->decoded_utf8);

    # dpkg strips whitespace (using isspace) from the right hand
    # side of the file name.

    # trim right
    s/\s+$// for @lines;

    my $position = 1;
    for my $line (@lines) {

        next
          unless length $line;

        my @words = split($SPACE, $line);
        my $relative = pop @words;

        my $conffile = Lintian::Conffiles::Entry->new;

        # path must be absolute
        if ($relative =~ s{^ / }{}x) {
            $conffile->is_relative($FALSE);
        } else {
            $conffile->is_relative($TRUE);
        }

        $conffile->instructions(\@words);
        $conffile->position($position);

        # but use relative path as key
        $self->by_file->{$relative} //= [];
        push(@{$self->by_file->{$relative}}, $conffile);

    } continue {
        ++$position;
    }

    return;
}

=item all

Returns a list of absolute filenames found for conffiles.

=cut

sub all {
    my ($self) = @_;

    return keys %{$self->by_file};
}

=item is_known (FILE)

Returns a truth value if FILE is listed in the conffiles control file.
If the control file is not present or FILE is not listed in it, it
returns C<undef>.

Note that FILE should be the filename relative to the package root
(even though the control file uses absolute paths).  If the control
file does relative paths, they are assumed to be relative to the
package root as well (and used without warning).

=cut

sub is_known {
    my ($self, $relative) = @_;

    return 1
      if exists $self->by_file->{$relative};

    return 0;
}

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

# -*- perl -*-
# Lintian::Processable::NotJustDocs

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

package Lintian::Processable::NotJustDocs;

use v5.20;
use warnings;
use utf8;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::NotJustDocs - Lintian interface to installable package data collection

=head1 SYNOPSIS

    my $processable = Lintian::Processable::Installable->new;

    my $is_empty = $processable->not_just_docs;

=head1 DESCRIPTION

Lintian::Processable::NotJustDocs provides an interface to package data for installation
packages.

=head1 INSTANCE METHODS

=over 4

=item not_just_docs

Returns a truth value if the package appears to be empty.

=cut

has not_just_docs => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $quoted_name = quotemeta($self->name);

        my $empty = 1;
        for my $item (@{$self->installed->sorted_list}) {

            # ignore directories
            next
              if $item->is_dir;

            # skip /usr/share/doc/$name symlinks.
            next
              if $item->name eq 'usr/share/doc/' . $self->name;

            # only look outside /usr/share/doc/$name directory
            next
              if $item->name =~ m{^usr/share/doc/$quoted_name};

            # except if it is a lintian override.
            next
              if $item->name =~ m{\A
                             # Except for:
                             usr/share/ (?:
                                 # lintian overrides
                                 lintian/overrides/$quoted_name(?:\.gz)?
                                 # reportbug scripts/utilities
                             | bug/$quoted_name(?:/(?:control|presubj|script))?
                             )\Z}xsm;

            return 0;
        }

        return 1;
    });

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

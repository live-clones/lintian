# -*- perl -*-
# Lintian::Processable::Source::Repacked -- interface to source package data collection

# Copyright © 2008 Russ Allbery
# Copyright © 2009 Raphael Geissert
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

package Lintian::Processable::Source::Repacked;

use v5.20;
use warnings;
use utf8;

use Lintian::Util qw($PKGREPACK_REGEX);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Source::Repacked - Lintian interface to source package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'source', '/path/to/lab-entry');
    my $collect = Lintian::Processable::Source::Repacked->new($name);
    if ($collect->native) {
        print encode_utf8("Package is native\n");
    }

=head1 DESCRIPTION

Lintian::Processable::Source::Repacked provides an interface to package data for source
packages.  It implements data collection methods specific to source
packages.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
source packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 INSTANCE METHODS

=over 4

=item repacked

Returns true if the source package has been "repacked" and false otherwise.
This is determined from the version name containing "dfsg" or similar.

=cut

has repacked => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $upstream = $self->changelog_version->upstream;

        return $upstream =~ $PKGREPACK_REGEX;
    });

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.
Amended by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

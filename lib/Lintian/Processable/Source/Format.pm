# -*- perl -*-
# Lintian::Processable::Source::Format -- interface to source package data collection

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

package Lintian::Processable::Source::Format;

use strict;
use warnings;

use Path::Tiny;

use constant EMPTY => q{};
use constant UNDERSCORE => q{_};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Source::Format - Lintian interface to source format

=head1 SYNOPSIS

    my $collect = Lintian::Processable::Source::Format->new;

=head1 DESCRIPTION

Lintian::Processable::Source::Format provides an interface to source format
information.

=head1 INSTANCE METHODS

=over 4

=item source_format

=cut

has source_format => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $format = $self->field('format') // '1.0';

        return $format;
    });

=item native

Returns true if the source package is native and false otherwise.
This is generally determined from the source format, though in the 1.0
case the nativeness is determined by looking for the diff.gz (using
the name of the source package and its version).

If the source format is 1.0 and the version number is absent, this
will return false (as native packages are a lot rarer than non-native
ones).

Note if the source format is missing, it is assumed to be a 1.0
package.

=cut

has native => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $format = $self->source_format;

        return 0
          if $format =~ /^\s*2\.0\s*$/;

        return 0
          if $format =~ /^\s*3\.0\s+\(quilt|git\)\s*$/;

        return 1
          if $format =~ /^\s*3\.0\s+\(native\)\s*$/;

        my $version = $self->field('version');
        return 0
          unless defined $version;

        # strip epoch
        $version =~ s/^\d+://;

        my $diffname = $self->name . UNDERSCORE . "$version.diff.gz";
        my $diffpath = path($self->groupdir)->child($diffname)->stringify;

        return 0
          if -f $diffpath;

        return 1;
    });

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.
Amended by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Relation(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
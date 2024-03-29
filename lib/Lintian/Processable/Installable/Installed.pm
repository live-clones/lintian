# -*- perl -*- Lintian::Processable::Installable::Installed
#
# Copyright (C) 2008, 2009 Russ Allbery
# Copyright (C) 2008 Frank Lichtenheld
# Copyright (C) 2012 Kees Cook
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Processable::Installable::Installed;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(uniq);

use Lintian::Index;

const my $SLASH => q{/};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Installable::Installed - access to collected data about the upstream (orig) sources

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Installable::Installed provides an interface to collected data about the upstream (orig) sources.

=head1 INSTANCE METHODS

=over 4

=item installed

Returns a index object representing installed files from a binary package.

=cut

has installed => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $index = Lintian::Index->new;
        my $archive = $self->basename;
        $index->identifier("$archive (installed)");
        $index->basedir($self->basedir . $SLASH . 'unpacked');

        # binary packages are anchored to the system root
        # allow absolute paths and symbolic links
        $index->anchored(1);

        my @command = (qw(dpkg-deb --fsys-tarfile), $self->path);
        my $errors = $index->create_from_piped_tar(\@command);

        my @messages = uniq split(/\n/, $errors);
        push(@{$index->unpack_messages}, @messages);

        return $index;
    }
);

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

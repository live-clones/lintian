# -*- perl -*- Lintian::Index::Objdump
#
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

package Lintian::Index::Objdump;

use strict;
use warnings;
use autodie;

use FileHandle;
use IO::Async::Loop;
use Path::Tiny;

use Lintian::Util qw(locate_helper_tool gzip safe_qx);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::Objdump - binary symbol information.

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Index::Objdump binary symbol information.

=head1 INSTANCE METHODS

=over 4

=item add_objdump

=cut

sub add_objdump {
    my ($self, $pkg, $type, $dir) = @_;

    my $helper = locate_helper_tool('coll/objdump-info-helper');

    chdir("$dir/unpacked");

    my $uncompressed;
    foreach my $path ($self->sorted_list) {

        next
          unless $path->is_file;

        my $name = $path->name;
        my $file_info = $self->fileinfo($name);

        # must be elf or static library
        next
          unless $file_info =~ m/\bELF\b/
          || ($file_info =~ m/\bcurrent ar archive\b/ && $name =~ m/\.a$/);

        my $output = safe_qx($helper, $name);
        $uncompressed .= $output;
    }

    # write even if empty; binaries check depends on it
    gzip($uncompressed // EMPTY, "$dir/objdump-info.gz");

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

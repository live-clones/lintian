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

use v5.20;
use warnings;
use utf8;
use autodie;

use Cwd;
use Path::Tiny;

use Lintian::IO::Async qw(safe_qx);
use Lintian::Util qw(locate_helper_tool);

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
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir);

    my $helper = locate_helper_tool('coll/objdump-info-helper');

    my @files = grep { $_->is_file } $self->sorted_list;
    for my $file (@files) {

        # must be elf or static library
        next
          unless $file->file_info =~ m/\bELF\b/
          || ( $file->file_info =~ m/\bcurrent ar archive\b/
            && $file->name =~ m/\.a$/);

        my $output = safe_qx($helper, $file->name);
        $file->objdump($output);
    }

    chdir($savedir);

    return;
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

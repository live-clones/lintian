# -*- perl -*- Lintian::Index::Strings
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

package Lintian::Index::Strings;

use strict;
use warnings;
use autodie;

use Path::Tiny;

use Lintian::Util qw(gzip safe_qx);

use constant DOT => q{.};
use constant GZ => q{gz};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::Strings - strings in binary files.

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Index::Strings strings in binary files.

=head1 INSTANCE METHODS

=over 4

=item add_strings

=cut

sub add_strings {
    my ($self, $pkg, $type, $dir) = @_;

    my $stringdir = "$dir/strings";
    path($stringdir)->remove_tree
      if -d $stringdir;

    # stop if we are asked to only remove the files
    return
      if $type =~ m/^remove-/;

    # the directory is required, even if it stays empty.
    path($stringdir)->mkpath
      unless -e $stringdir;

    foreach my $file ($self->sorted_list) {

        next
          unless $file->is_file;

        next
          if $file->name =~ m,^usr/lib/debug/,;

        # skip non-binaries
        next
          unless $self->fileinfo($file->name) =~ m/\bELF\b/o;

        # prior implementations sometimes made the list unique
        my $allstrings= safe_qx('strings', '--all', '--',$file->unpacked_path);

        # calculate destination path
        my $relative = $file->name . DOT . GZ;
        my $zippath = path($relative)->absolute($stringdir)->stringify;

        # make sure destination folder exists
        path($zippath)->parent->mkpath
          unless path($zippath)->parent->exists;

        # write file
        gzip($allstrings, $zippath);
    }

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

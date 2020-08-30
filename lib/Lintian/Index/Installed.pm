# -*- perl -*- Lintian::Index::Installed
#
# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Index::Installed;

use v5.20;
use warnings;
use utf8;
use autodie;

use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Index',
  'Lintian::Index::Ar',
  'Lintian::Index::FileInfo',
  'Lintian::Index::Java',
  'Lintian::Index::Md5sums',
  'Lintian::Index::Objdump',
  'Lintian::Index::Scripts',
  'Lintian::Index::Strings';

=encoding utf-8

=head1 NAME

Lintian::Index::Installed -- An index of an installed file set

=head1 SYNOPSIS

 use Lintian::Index::Installed;

 # Instantiate via Lintian::Index::Installed
 my $orig = Lintian::Index::Installed->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
installed file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4

=item collect

=cut

sub collect {
    my ($self, $processable_dir) = @_;

    # binary packages are anchored to the system root
    # allow absolute paths and symbolic links
    $self->anchored(1);

    my @command = (qw(dpkg-deb --fsys-tarfile), "$processable_dir/deb");
    my ($extract_errors, $index_errors)
      = $self->create_from_piped_tar(\@command);

    $self->load;

    $self->add_md5sums;
    $self->add_ar;

    $self->add_fileinfo;
    $self->add_scripts;
    $self->add_objdump;
    $self->add_strings;
    $self->add_java;

    path("$processable_dir/unpacked-errors")->spew_utf8($extract_errors)
      if length $extract_errors;

    path("$processable_dir/index-errors")->spew_utf8($index_errors)
      if length $index_errors;

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.
Substantial portions adapted from code written by Russ Allbery, Niels Thykier, and others.

=head1 SEE ALSO

lintian(1)

L<Lintian::Index>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

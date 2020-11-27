# files/names -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::names;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use Unicode::UTF8 qw(valid_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $FNAMES = Lintian::Data->new('files/fnames', qr/\s*\~\~\s*/);

my %PATH_DIRECTORIES = map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin/ usr/games/ );

sub visit_installed_files {
    my ($self, $file) = @_;

    # unusual characters
    if ($file->name =~ m,\s+\z,) {
        $self->hint('file-name-ends-in-whitespace', $file->name);
    }
    if ($file->name =~ m,/\*\z,) {
        $self->hint('star-file', $file->name);
    }
    if ($file->name =~ m,/-\z,) {
        $self->hint('hyphen-file', $file->name);
    }

    # check for generic bad filenames
    foreach my $tag ($FNAMES->all()) {

        my $regex = $FNAMES->value($tag);

        $self->hint($tag, $file->name)
          if $file->name =~ m/$regex/;
    }

    if (exists($PATH_DIRECTORIES{$file->dirname})) {

        $self->hint('file-name-in-PATH-is-not-ASCII', $file->name)
          if $file->basename !~ m{\A [[:ascii:]]++ \Z}xsm;

        $self->hint('zero-byte-executable-in-path', $file->name)
          if $file->is_regular_file
          and $file->is_executable
          and $file->size == 0;

    } elsif (!valid_utf8($file->name)) {
        $self->hint('shipped-file-without-utf8-name', $file->name);
    }

    return;
}

sub source {
    my ($self) = @_;

    unless ($self->processable->native) {

        my @orig_non_utf8 = grep { !valid_utf8($_->name) }
          $self->processable->orig->sorted_list;

        $self->hint('upstream-file-without-utf8-name', $_->name)
          for @orig_non_utf8;
    }

    my @patched = map { $_->name } $self->processable->patched->sorted_list;
    my @orig = map { $_->name } $self->processable->orig->sorted_list;

    my $lc= List::Compare->new(\@patched, \@orig);
    my @created = $lc->get_Lonly;

    my @non_utf8 = grep { !valid_utf8($_) } @created;

    # exclude quilt directory
    my @maintainer_fault = grep { !m{^.pc/} } @non_utf8;

    if ($self->processable->native) {
        $self->hint('native-source-file-without-utf8-name', $_)
          for @maintainer_fault;

    } else {
        $self->hint('patched-file-without-utf8-name', $_)for @maintainer_fault;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

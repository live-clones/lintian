# md5sums -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::md5sums;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::Compare;
use Path::Tiny;
use Try::Tiny;

use Lintian::Util qw(read_md5sums drop_relative_prefix);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has only_conffiles => (is => 'rwp', default => 1);

sub files {
    my ($self, $file) = @_;

    # check if package contains non-conffiles
    # debhelper doesn't create entries in md5sums
    # for conffiles since this information would
    # be redundant

    # Skip non-files, they will not appear in the md5sums file
    return
      unless $file->is_regular_file;

    $self->_set_only_conffiles(0)
      unless $self->processable->is_conffile($file);

    return;
}

sub binary {
    my ($self) = @_;

    my $control = $self->processable->control->lookup('md5sums');

    # Is there an md5sums control file?
    unless ($control) {

        # ignore if package contains no files
        return
          if -z path($self->processable->groupdir)->child('md5sums')
          ->stringify;

        $self->tag('no-md5sums-control-file')
          unless $self->only_conffiles;

        return;
    }

    # The md5sums file should not be a symlink.  If it is, the best
    # we can do is to leave it alone.
    return
      if $control->is_symlink;

    return
      unless $control->is_open_ok;

    # Is it empty? Then skip it. Tag will be issued by control-files
    return
      if $control->size == 0;

    my $text = $control->bytes;

    my ($md5sums, $errors) = read_md5sums($text);

    $self->tag('malformed-md5sums-control-file', $_)for @{$errors};

    my %noprefix
      = map { drop_relative_prefix($_) => $md5sums->{$_} } keys %{$md5sums};

    my @listed = keys %noprefix;
    my @found = grep { $_->is_file} $self->processable->installed->sorted_list;

    my $lc = List::Compare->new(\@listed, \@found);

    # find files that should exist but do not
    $self->tag('md5sums-lists-nonexistent-file', $_)for $lc->get_Lonly;

    # find files that should be listed but are not
    for my $name ($lc->get_Ronly) {

        $self->tag('file-missing-in-md5sums', $name)
          unless $self->processable->is_conffile($name)
          || $name =~ m%^var/lib/[ai]spell/.%;
    }

    # checksum should match for common files
    for my $name ($lc->get_intersection) {

        my $file = $self->processable->installed->lookup($name);

        $self->tag('md5sum-mismatch', $name)
          unless $file->md5sum eq $noprefix{$name};
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

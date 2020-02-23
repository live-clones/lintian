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

use strict;
use warnings;
use autodie;

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

sub breakdown {
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
    }

    return;
}

sub binary {
    my ($self) = @_;

    my $control = $self->processable->control->lookup('md5sums');

    # Is there an md5sums control file?
    return
      unless $control;

    # The md5sums file should not be a symlink.  If it is, the best
    # we can do is to leave it alone.
    return
      if $control->is_symlink;

    return
      unless $control->is_open_ok;

    # Is it empty? Then skip it. Tag will be issued by control-files
    return
      if $control->size == 0;

    my $text = path($control->unpacked_path)->slurp;
    my ($md5sums, $errors) = read_md5sums($text);

    $self->tag('malformed-md5sums-control-file', $_)for @{$errors};

    my %noprefix
      = map { drop_relative_prefix($_) => $md5sums->{$_} } keys %{$md5sums};

    # iterate over files found in control file
    for my $file (keys %noprefix) {

        my $calculated = $self->processable->md5sums->{$file};
        unless (defined $calculated) {

            $self->tag('md5sums-lists-nonexistent-file', $file);
            next;
        }

        $self->tag('md5sum-mismatch', $file)
          unless $calculated eq $noprefix{$file};
    }

    # iterate over files present in package
    for my $file (keys %{ $self->processable->md5sums }) {

        next
          if $noprefix{$file};

        $self->tag('file-missing-in-md5sums', $file)
          unless $self->processable->is_conffile($file)
          || $file =~ m%^var/lib/[ai]spell/.%;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

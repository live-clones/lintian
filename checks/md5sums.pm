# md5sums -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

use Moo;

use Lintian::Util qw(dequote_name);

with('Lintian::Check');

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
      unless $self->info->is_conffile($file);

    return;
}

sub breakdown {
    my ($self) = @_;

    my $control = $self->info->control_index('md5sums');

    # Is there an md5sums control file?
    unless ($control) {

        # ignore if package contains no files
        return
          if -z $self->info->lab_data_path('md5sums');

        $self->tag('no-md5sums-control-file')
          unless $self->only_conffiles;
    }

    return;
}

sub binary {
    my ($self) = @_;

    my $info = $self->info;

    my $control = $info->control_index('md5sums');
    my (%control_entry, %info_entry);

    # Is there an md5sums control file?
    return
      unless $control;

    # The md5sums file should not be a symlink.  If it is, the best
    # we can do is to leave it alone.
    return if $control->is_symlink or not $control->is_open_ok;

    # Is it empty? Then skip it. Tag will be issued by control-files
    return if $control->size == 0;

    # read in md5sums control file
    my $fd = $control->open;
  LINE:
    while (my $line = <$fd>) {
        chop($line);
        next LINE if $line =~ m/^\s*$/;
        if ($line
            =~ m{^(?'escaped'\\)?(?'md5sum'[a-f0-9]+)\s*(?:\./)?(?'name'\S.*)$}
        ) {
            my $md5sum = $+{'md5sum'};
            if(length($md5sum) != 32) {
                $self->tag('malformed-md5sums-control-file', "line $.");
                next LINE;
            }
            my $name = $+{'name'};
            my $escaped = $+{'escaped'};
            if ($escaped) {
                $name = dequote_name($name);
            }
            $control_entry{$name} = $md5sum;
        } else {
            $self->tag('malformed-md5sums-control-file', "line $.");
            next LINE;
        }
    }
    close($fd);

    for my $file (keys %control_entry) {

        my $md5sum = $info->md5sums->{$file};
        if (not defined $md5sum) {
            $self->tag('md5sums-lists-nonexistent-file', $file);
        } elsif ($md5sum ne $control_entry{$file}) {
            $self->tag('md5sum-mismatch', $file);
        }

        delete $info_entry{$file};
    }
    for my $file (keys %{ $info->md5sums }) {
        next if $control_entry{$file};
        $self->tag('file-missing-in-md5sums', $file)
          unless ($info->is_conffile($file)
            || $file =~ m%^var/lib/[ai]spell/.%o);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

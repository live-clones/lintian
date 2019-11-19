# duplicate-files -- lintian check script -*- perl -*-

# Copyright (C) 2011 Niels Thykier
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

package Lintian::duplicate_files;

use strict;
use warnings;
use autodie;

use List::MoreUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has md5map => (is => 'rwp', default => sub{ {} });

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_regular_file;

    # Ignore empty files; in some cases (e.g. python) a file is
    # required even if it is empty and we are never looking at a
    # substantial gain in such a case.  Also see #632789
    return
      unless $file->size;

    my $md5 = $self->processable->md5sums->{$file};
    return
      unless defined $md5;

    return
      unless $file =~ m{\A usr/share/doc/}xsmo;

    $self->md5map->{$md5} = []
      unless defined $self->md5map->{$md5};

    push(@{$self->md5map->{$md5}}, $file);

    return;
}

sub breakdown {
    my ($self) = @_;

    foreach my $md5 (keys %{$self->md5map}){
        my @files = @{ $self->md5map->{$md5} };

        next
          if scalar @files < 2;

        if (any { m,changelog,io} @files) {
            $self->tag('duplicate-changelog-files', sort @files);

        } else {
            $self->tag('duplicate-files', sort @files);
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

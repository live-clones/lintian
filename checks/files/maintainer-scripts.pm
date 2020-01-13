# files/maintainer-scripts -- lintian check script -*- perl -*-

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

package Lintian::files::maintainer_scripts;

use strict;
use warnings;
use autodie;

use List::MoreUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    # get maintainer scripts
    my @names = keys %{$self->processable->control_scripts};
    my @files
      =map { $self->processable->control_index_resolved_path($_) } @names;

    for my $file (@files) {

        next
          unless $file && $file->is_open_ok;

        # why is lintian exempt from this check?
        next
          if $self->processable->source eq 'lintian';

        my %checks;

        $checks{'missing-depends-on-sensible-utils'}
          = '(?:select-editor|sensible-(?:browser|editor|pager))\b'
          unless $file->name =~ m,^usr/share/(?:doc|locale)/,
          || $self->processable->relation('all')->implies('sensible-utils')
          || $self->processable->source eq 'sensible-utils';

        $checks{'uses-dpkg-database-directly'} = '/var/lib/dpkg'
          unless $file->name =~ m,^usr/share/(?:doc|locale)/,
          || $file->basename =~ m/^README(?:\..*)?$/
          || $file->basename =~ m/^changelog(?:\..*)?$/i
          || $file->basename =~ m/\.(?:html|txt)$/i
          || $self->processable->field('section', '') eq 'debian-installer'
          || any { $_ eq $self->processable->source }
        qw(base-files dpkg lintian);

        $checks{'file-references-package-build-path'}
          = quotemeta($self->build_path)
          if $self->build_path =~ m,^/.+,g;

        my $fd = $file->open;
        while (<$fd>) {
            for my $tag (keys %checks) {
                $self->tag($tag, $file->name, "(line $.)")
                  if $_ =~ $checks{$tag};
            }
        }
        close $fd;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

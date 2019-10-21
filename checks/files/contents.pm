# files/contents -- lintian check script -*- perl -*-

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

package Lintian::files::contents;

use strict;
use warnings;
use autodie;

use Moo;

use List::MoreUtils qw(none);

use Lintian::SlidingWindow;

with('Lintian::Check');

has bin_binaries => (is => 'rwp', default => sub { [] });

sub setup {
    my ($self) = @_;

    for my $file ($self->info->sorted_index) {

        next
          unless $file->is_file;

        # for /usr/sbin/foo check for references to /usr/bin/foo
        push(@{$self->bin_binaries}, '/'.($1 // '')."bin/$2")
          if $file->name =~ m,^(usr/)?sbin/(.+),;
    }

    return;
}

sub breakdown {
    my ($self) = @_;

    $self->_set_bin_binaries([]);
    return;
}

sub get_checks_for_file {
    my ($self, $file) = @_;

    my %checks;

    return %checks
      if $self->processable->pkg_src eq 'lintian';

    $checks{'missing-depends-on-sensible-utils'}
      = '(?:select-editor|sensible-(?:browser|editor|pager))\b'
      if $file->name !~ m,^usr/share/(?:doc|locale)/,
      and not $self->info->relation('all')->implies('sensible-utils');

    $checks{'uses-dpkg-database-directly'} = '/var/lib/dpkg'
      if $file->name !~ m,^usr/share/(?:doc|locale)/,
      and $file->basename !~ m/^README(?:\..*)?$/
      and $file->basename !~ m/^changelog(?:\..*)?$/i
      and $file->basename !~ m/\.(?:html|txt)$/i
      and $self->info->field('section', '') ne 'debian-installer'
      and none { $_ eq $self->processable->pkg_src }
    qw(base-files dpkg lintian);

    $checks{'file-references-package-build-path'}= quotemeta($self->build_path)
      if $self->build_path =~ m,^/.+,g;

    # If we have a /usr/sbin/foo, check for references to /usr/bin/foo
    $checks{'bin-sbin-mismatch'}
      = '(' . join('|', @{$self->bin_binaries}) . ')'
      if @{$self->bin_binaries};

    return %checks;
}

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    my %checks = $self->get_checks_for_file($file);

    if (%checks) {

        my $stringsfd = $self->info->strings($file);
        my $strings = do { local $/; <$stringsfd> };
        close($stringsfd)
          or warn "Error closing strings fd: $!";

        foreach my $tag (sort keys %checks) {
            my $regex = $checks{$tag};

            # prefer strings(1) output (eg. for ELF) if we have it
            if ($strings) {
                $self->tag($tag, $file->name)
                  if $strings =~ m,^\Q$regex\E,m;

            } else {
                my $fd = $file->open(':raw');
                my $sfd = Lintian::SlidingWindow->new($fd);
                while (my $block = $sfd->readwindow) {
                    next
                      unless $block =~ $regex;

                    $self->tag($tag, $file->name);
                    last;
                }
                close($fd);
            }
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

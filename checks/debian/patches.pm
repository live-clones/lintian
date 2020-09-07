# debian/patches -- lintian check script -*- perl -*-
#
# Copyright © 2007 Marc Brockschmidt
# Copyright © 2008 Raphael Hertzog
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::debian::patches;

use v5.20;
use warnings;
use utf8;
use autodie;

use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my @patch_system;

    # Get build deps so we can decide which build system the
    # maintainer meant to use:
    my $build_deps = $self->processable->relation('Build-Depends-All');

    # Get source package format
    my $source_format = $self->processable->fields->value('Format');
    my $quilt_format = ($source_format =~ /3\.\d+ \(quilt\)/) ? 1 : 0;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless defined $debian_dir;

    my $patch_dir = $debian_dir->resolve_path('patches');

    # Find debian/patches/series, assuming debian/patches is a (symlink to a)
    # dir.  There are cases, where it is a file (ctwm: #778556)
    my $patch_series
      = $self->processable->patched->resolve_path('debian/patches/series');

    # Count number of patches
    my $num_patches = 0;
    if (defined $patch_series) {
        open(my $fd, '<', $patch_series->unpacked_path);
        while (my $line = <$fd>) {
            chomp $line;
            # Remove comments
            $line =~ s/(?:^|\s+)#.*$//;
            $num_patches++
              if $line =~ /(?:^|\s+)\S+.*$/;
        }
        close($fd);
    }
    $self->tag('number-of-patches', $num_patches);

    push(@patch_system, 'dpatch')
      if $build_deps->implies('dpatch');

    push(@patch_system, 'quilt')
      if $quilt_format || $build_deps->implies('quilt');

    $self->tag('patch-system', $_) for @patch_system;

    $self->tag('more-than-one-patch-system')
      if @patch_system > 1;

    if (@patch_system && !$quilt_format) {

        my $readme = $debian_dir->resolve_path('README.source');
        $self->tag('patch-system-but-no-source-readme')
          unless defined $readme;
    }

    my @direct_changes;

    my @lines = path($self->processable->diffstat)->lines_utf8({chomp => 1});
    for my $line (@lines) {

        my $file = $line;
        $file =~ s{\s+\|.*$}{}s;

        # trim both ends
        $file =~ s/^\s+|\s+$//g;

        die "syntax error in diffstat file: $line"
          unless length $file;

        push(@direct_changes, $file) unless $file =~ m{^debian/};
    }

    if (@direct_changes) {

        my $files = $direct_changes[0];
        $files .= " and $#direct_changes more"
          if @direct_changes > 1;

        $self->tag('patch-system-but-direct-changes-in-diff', $files)
          if @patch_system;

        $self->tag('direct-changes-in-diff-but-no-patch-system', $files)
          unless @patch_system;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

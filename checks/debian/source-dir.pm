# debian/source directory content -- lintian check script -*- perl -*-

# Copyright (C) 2010 by Raphaël Hertzog
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

package Lintian::debian::source_dir;

use strict;
use warnings;
use autodie;

use List::MoreUtils qw(any);

use Lintian::Data;

use Moo;
use namespace::clean;

with 'Lintian::Check';

our %KNOWN_FORMATS = map { $_ => 1 }
  ('1.0', '2.0', '3.0 (quilt)', '3.0 (native)', '3.0 (git)', '3.0 (bzr)');

my %OLDER_FORMATS = map { $_ => 1 }('1.0');

our $KNOWN_FILES = Lintian::Data->new('debian-source-dir/known-files');

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $dsrc = $processable->index_resolved_path('debian/source/');
    my ($format_file, $git_pfile, $format, $format_extra);

    $format_file = $dsrc->child('format') if $dsrc;

    if ($format_file and $format_file->is_open_ok) {
        my $fd = $format_file->open;
        $format = <$fd>;
        chomp $format;
        close($fd);
        $format_extra = '';
        die "unknown source format $format" unless $KNOWN_FORMATS{$format};
    } else {
        $self->tag('missing-debian-source-format');
        $format = '1.0';
        $format_extra = 'implicit';
    }
    if ($format eq '1.0') {
        $format_extra .= ' ' if $format_extra;
        if ($processable->diffstat) {
            $format_extra .= 'non-native';
        } else {
            $format_extra .= 'native';
        }
    }
    my $format_info = $format;
    $format_info .= " [$format_extra]"
      if $format_extra;
    $self->tag('source-format', $format_info);

    $self->tag('older-source-format', $format) if $OLDER_FORMATS{$format};

    return if not $dsrc;

    $git_pfile = $dsrc->child('git-patches');

    if ($git_pfile and $git_pfile->is_open_ok and $git_pfile->size != 0) {
        my $git_patches_fd = $git_pfile->open;
        if (any { !/^\s*+#|^\s*+$/o} <$git_patches_fd>) {
            my $dpseries
              = $processable->index_resolved_path('debian/patches/series');
            # gitpkg does not create series as a link, so this is most likely
            # a traversal attempt.
            if (not $dpseries or not $dpseries->is_open_ok) {
                $self->tag('git-patches-not-exported');
            } else {
                my $series_fd = $dpseries->open;
                my $comment_line = <$series_fd>;
                my $count = grep { !/^\s*+\#|^\s*+$/o } <$series_fd>;
                $self->tag('git-patches-not-exported')
                  unless (
                    $count
                    && ($comment_line
                        =~ m/^\s*\#.*quilt-patches-deb-export-hook/o));
                close($series_fd);
            }
        }
        close($git_patches_fd);
    }

    for my $path ($dsrc->children) {
        my $file = $path->basename;
        $self->tag('unknown-file-in-debian-source', $file)
          unless $KNOWN_FILES->known($file);
    }

    my $options = $processable->index_resolved_path('debian/source/options');
    if ($options and $options->is_open_ok) {
        my $fd = $options->open;
        while (<$fd>) {
            $self->tag('debian-source-options-has-custom-compression-settings',
                $1, "(line $.)")
              if m/^\s*(compression(?:-level)?\s*=\s+\S+)\n/;
        }
        close($fd);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

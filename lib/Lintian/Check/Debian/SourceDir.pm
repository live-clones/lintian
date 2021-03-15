# debian/source directory content -- lintian check script -*- perl -*-

# Copyright © 2010 by Raphaël Hertzog
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

package Lintian::Check::Debian::SourceDir;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

our %KNOWN_FORMATS = map { $_ => 1 }
  ('1.0', '2.0', '3.0 (quilt)', '3.0 (native)', '3.0 (git)', '3.0 (bzr)');

my %OLDER_FORMATS = map { $_ => 1 }('1.0');

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $dsrc = $processable->patched->resolve_path('debian/source/');
    my ($format_file, $git_pfile, $format, $format_extra);

    $format_file = $dsrc->child('format') if $dsrc;

    if ($format_file and $format_file->is_open_ok) {

        open(my $fd, '<', $format_file->unpacked_path)
          or die encode_utf8('Cannot open ' . $format_file->unpacked_path);

        $format = <$fd>;
        chomp $format;
        close($fd);
        $format_extra = $EMPTY;
        die encode_utf8("unknown source format $format")
          unless $KNOWN_FORMATS{$format};
    } else {
        $self->hint('missing-debian-source-format');
        $format = '1.0';
        $format_extra = 'implicit';
    }
    if ($format eq '1.0') {
        $format_extra .= $SPACE if $format_extra;
        if (keys %{$processable->diffstat}) {
            $format_extra .= 'non-native';
        } else {
            $format_extra .= 'native';
        }
    }
    my $format_info = $format;
    $format_info .= " [$format_extra]"
      if $format_extra;
    $self->hint('source-format', $format_info);

    $self->hint('older-source-format', $format) if $OLDER_FORMATS{$format};

    return if not $dsrc;

    $git_pfile = $dsrc->child('git-patches');

    if ($git_pfile and $git_pfile->is_open_ok and $git_pfile->size != 0) {

        open(my $git_patches_fd, '<', $git_pfile->unpacked_path)
          or die encode_utf8('Cannot open ' . $git_pfile->unpacked_path);

        if (any { !/^\s*+#|^\s*+$/} <$git_patches_fd>) {
            my $dpseries
              = $processable->patched->resolve_path('debian/patches/series');
            # gitpkg does not create series as a link, so this is most likely
            # a traversal attempt.
            if (not $dpseries or not $dpseries->is_open_ok) {
                $self->hint('git-patches-not-exported');
            } else {
                open(my $series_fd, '<', $dpseries->unpacked_path)
                  or
                  die encode_utf8('Cannot open ' . $dpseries->unpacked_path);

                my $comment_line = <$series_fd>;
                my $count = grep { !/^\s*+\#|^\s*+$/ } <$series_fd>;
                $self->hint('git-patches-not-exported')
                  unless ($count
                    && ($comment_line
                        =~ /^\s*\#.*quilt-patches-deb-export-hook/));
                close($series_fd);
            }
        }
        close($git_patches_fd);
    }

    my $KNOWN_FILES
      = $self->profile->load_data('debian-source-dir/known-files');

    my @files = grep { !$_->is_dir } $dsrc->children;
    for my $file (@files) {

        $self->hint('unknown-file-in-debian-source', $file->basename)
          unless $KNOWN_FILES->recognizes($file->basename);
    }

    my $options = $processable->patched->resolve_path('debian/source/options');
    if ($options and $options->is_open_ok) {

        open(my $fd, '<', $options->unpacked_path)
          or die encode_utf8('Cannot open ' . $options->unpacked_path);

        while (my $line = <$fd>) {
            $self->hint('custom-compression-in-debian-source-options',
                $1, "(line $.)")
              if $line =~ /^\s*(compression(?:-level)?\s*=\s+\S+)\n/;
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

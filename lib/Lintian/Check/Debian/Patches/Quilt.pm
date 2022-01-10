# debian/patches/quilt -- lintian check script -*- perl -*-
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

package Lintian::Check::Debian::Patches::Quilt;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(decode_utf8 encode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);
use Lintian::Spelling qw(check_spelling);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $PATCH_DESC_TEMPLATE =>
  'TODO: Put a short summary on the line above and replace this paragraph';
const my $EMPTY => q{};

sub spelling_tag_emitter {
    my ($self, $tag_name, $item, @orig_args) = @_;

    my $pointer = $item->pointer($.);

    return sub {
        return $self->pointed_hint($tag_name, $pointer, @orig_args, @_);
    };
}

sub source {
    my ($self) = @_;

    my $build_deps = $self->processable->relation('Build-Depends-All');

    my $source_format = $self->processable->fields->value('Format');
    my $quilt_format = ($source_format =~ /3\.\d+ \(quilt\)/) ? 1 : 0;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless defined $debian_dir;

    my $patch_dir = $debian_dir->resolve_path('patches');
    my %known_files;

    # Find debian/patches/series, assuming debian/patches is a (symlink to a)
    # dir.  There are cases, where it is a file (ctwm: #778556)
    my $patch_series;
    $patch_series
      = $self->processable->patched->resolve_path('debian/patches/series');

    # 3.0 (quilt) sources do not need quilt
    unless ($quilt_format) {

        $self->hint('quilt-build-dep-but-no-series-file')
          if $build_deps->satisfies('quilt')
          && (!defined $patch_series || !$patch_series->is_open_ok);

        $self->pointed_hint('quilt-series-but-no-build-dep',
            $patch_series->pointer)
          if $patch_series
          && $patch_series->is_file
          && !$build_deps->satisfies('quilt');
    }

    return
      unless $quilt_format || $build_deps->satisfies('quilt');

    if ($patch_series && $patch_series->is_open_ok) {

        my @patch_names;

        open(my $series_fd, '<', $patch_series->unpacked_path)
          or die encode_utf8('Cannot open ' . $patch_series->unpacked_path);

        my $position = 1;
        while (my $line = <$series_fd>) {

            # Strip comment
            $line =~ s/(?:^|\s+)#.*$//;

            if (rindex($line,"\n") < 0) {
                $self->pointed_hint('quilt-series-without-trailing-newline',
                    $patch_series->pointer);
            }

            # trim both ends
            $line =~ s/^\s+|\s+$//g;

            next
              unless length $line;

            if ($line =~ m{^(\S+)\s+(\S.*)$}) {

                my $patch = $1;
                my $patch_options = $2;

                push(@patch_names, $patch);

                $self->pointed_hint('quilt-patch-with-non-standard-options',
                    $patch_series->pointer($position), $line)
                  unless $patch_options eq '-p1';

            } else {
                push(@patch_names, $line);
            }

        } continue {
            ++$position;
        }

        close $series_fd;

        my @patch_files;
        for my $name (@patch_names) {

            my $item = $patch_dir->resolve_path($name);

            if (defined $item && $item->is_file) {
                push(@patch_files, $item);

            } else {
                $self->pointed_hint(
                    'quilt-series-references-non-existent-patch',
                    $patch_series->pointer, $name);
            }
        }

        for my $item (@patch_files) {

            next
              unless $item->is_open_ok;

            my $description = $EMPTY;
            my $has_template_description = 0;

            open(my $patch_fd, '<', $item->unpacked_path)
              or die encode_utf8('Cannot open ' . $item->unpacked_path);

            while (my $line = <$patch_fd>) {

                # stop if something looking like a patch starts:
                last
                  if $line =~ /^---/;

                next
                  if $line =~ /^\s*$/;

                # Skip common "lead-in" lines
                $description .= $line
                  unless $line =~ m{^(?:Index: |=+$|diff .+|index |From: )};

                $has_template_description = 1
                  if $line =~ / \Q$PATCH_DESC_TEMPLATE\E /msx;
            }
            close $patch_fd;

            $self->pointed_hint('quilt-patch-missing-description',
                $item->pointer)
              unless length $description;

            $self->pointed_hint('quilt-patch-using-template-description',
                $item->pointer)
              if $has_template_description;

            $self->check_patch($item, $description);
        }
    }

    if ($quilt_format) { # 3.0 (quilt) specific checks
         # Format 3.0 packages may generate a debian-changes-$version patch
        my $version = $self->processable->fields->value('Version');
        my $patch_header= $debian_dir->resolve_path('source/patch-header');
        my $versioned_patch;

        $versioned_patch= $patch_dir->resolve_path("debian-changes-$version")
          if $patch_dir;

        if (defined $versioned_patch && $versioned_patch->is_file) {

            $self->pointed_hint('format-3.0-but-debian-changes-patch',
                $versioned_patch->pointer)
              if !defined $patch_header || !$patch_header->is_file;
        }
    }

    if ($patch_dir and $patch_dir->is_dir and $source_format ne '2.0') {
        # Check all series files, including $vendor.series
        for my $item ($patch_dir->children) {
            next
              unless $item->name =~ /\/(.+\.)?series$/;
            next
              unless $item->is_open_ok;

            $known_files{$item->basename}++;

            open(my $fd, '<', $item->unpacked_path)
              or die encode_utf8('Cannot open ' . $item->unpacked_path);

            while (my $line = <$fd>) {
                $known_files{$1}++
                  if $line =~ m{^\s*(?:#+\s*)?(\S+)};
            }
            close($fd);

            $self->pointed_hint('package-uses-vendor-specific-patch-series',
                $item->pointer)
              if $item->name =~ m{ [.]series $}x;
        }

        for my $item ($patch_dir->descendants) {
            next
              if $item->basename =~ /^README(\.patches)?$/
              || $item->basename =~ /\.in/g;

            # Use path relative to debian/patches for "subdir/foo"
            my $name = substr($item, length $patch_dir);

            $self->pointed_hint(
                'patch-file-present-but-not-mentioned-in-series',
                $item->pointer)
              unless $known_files{$name} || $item->is_dir;
        }
    }

    return;
}

# Checks on patches common to all build systems.
sub check_patch {
    my ($self, $item, $description) = @_;

    unless (any { /(spelling|typo)/i } ($item->name, $description)) {
        my $tag_emitter
          = $self->spelling_tag_emitter('spelling-error-in-patch-description',
            $item);
        check_spelling($self->data, $description,
            $self->group->spelling_exceptions,
            $tag_emitter, 0);
    }

    # Use --strip=1 to strip off the first layer of directory in case
    # the parent directory in which the patches were generated was
    # named "debian".  This will produce false negatives for --strip=0
    # patches that modify files in the debian/* directory, but as of
    # 2010-01-01, all cases where the first level of the patch path is
    # "debian/" in the archive are false positives.
    my $bytes = safe_qx('lsdiff', '--strip=1', $item->unpacked_path);
    my $output = decode_utf8($bytes);

    my @debian_files = ($output =~ m{^((?:\./)?debian/.*)$}ms);

    $self->pointed_hint('patch-modifying-debian-files', $item->pointer, $_)
      for @debian_files;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

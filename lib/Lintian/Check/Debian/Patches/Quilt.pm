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
    my ($self, @orig_args) = @_;

    return sub {
        return $self->hint(@orig_args, @_);
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

        $self->hint('quilt-series-but-no-build-dep')
          if $patch_series
          && $patch_series->is_file
          && !$build_deps->satisfies('quilt');
    }

    return
      unless $quilt_format || $build_deps->satisfies('quilt');

    if ($patch_series && $patch_series->is_open_ok) {

        my (@patch_names, @badopts);

        open(my $series_fd, '<', $patch_series->unpacked_path)
          or die encode_utf8('Cannot open ' . $patch_series->unpacked_path);

        while (my $patch = <$series_fd>) {
            $patch =~ s/(?:^|\s+)#.*$//; # Strip comment
            if (rindex($patch,"\n") < 0) {
                $self->hint('quilt-series-without-trailing-newline');
            }

            # trim both ends
            $patch =~ s/^\s+|\s+$//g;

            next if $patch eq $EMPTY;
            if ($patch =~ m{^(\S+)\s+(\S.*)$}) {
                my $patch_options;
                ($patch, $patch_options) = ($1, $2);
                if ($patch_options ne '-p1') {
                    push(@badopts, $patch);
                }
            }
            push(@patch_names, $patch);
        }
        close($series_fd);

        $self->hint('quilt-patch-with-non-standard-options', @badopts)
          if @badopts;

        my @patch_files;
        for my $name (@patch_names) {

            my $file = $patch_dir->resolve_path($name);

            if (defined $file && $file->is_file) {
                push(@patch_files, $file);

            } else {
                $self->hint('quilt-series-references-non-existent-patch',
                    $name);
            }
        }

        for my $file (@patch_files) {

            next
              unless $file->is_open_ok;

            my $description = $EMPTY;
            my $has_template_description = 0;

            open(my $patch_fd, '<', $file->unpacked_path)
              or die encode_utf8('Cannot open ' . $file->unpacked_path);

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
            close($patch_fd);

            $self->hint('quilt-patch-missing-description', $file->name)
              unless length $description;

            $self->hint('quilt-patch-using-template-description', $file->name)
              if $has_template_description;

            $self->check_patch($file, $description);
        }
    }

    if ($quilt_format) { # 3.0 (quilt) specific checks
         # Format 3.0 packages may generate a debian-changes-$version patch
        my $version = $self->processable->fields->value('Version');
        my $patch_header= $debian_dir->resolve_path('source/patch-header');
        my $versioned_patch;

        $versioned_patch= $patch_dir->resolve_path("debian-changes-$version")
          if $patch_dir;

        if ($versioned_patch and $versioned_patch->is_file) {
            if (not $patch_header or not $patch_header->is_file) {
                $self->hint('format-3.0-but-debian-changes-patch');
            }
        }
    }

    if ($patch_dir and $patch_dir->is_dir and $source_format ne '2.0') {
        # Check all series files, including $vendor.series
        for my $file ($patch_dir->children) {
            next
              unless $file =~ /\/(.+\.)?series$/;
            next
              unless $file->is_open_ok;

            $known_files{$file->basename}++;

            open(my $fd, '<', $file->unpacked_path)
              or die encode_utf8('Cannot open ' . $file->unpacked_path);

            while (my $line = <$fd>) {
                $known_files{$1}++
                  if $line =~ m{^\s*(?:#+\s*)?(\S+)};
            }
            close($fd);

            $self->hint('package-uses-vendor-specific-patch-series', $file)
              if $file =~ /\.series$/;
        }

        for my $file ($patch_dir->descendants) {
            next
              if $file->basename =~ /^README(\.patches)?$/
              or $file->basename =~ /\.in/g;

            # Use path relative to debian/patches for "subdir/foo"
            my $name = substr($file, length $patch_dir);
            $self->hint('patch-file-present-but-not-mentioned-in-series',$name)
              unless $known_files{$name} or $file->is_dir;
        }
    }

    return;
}

# Checks on patches common to all build systems.
sub check_patch {
    my ($self, $patch_file, $description) = @_;

    unless (any { /(spelling|typo)/i } ($patch_file, $description)) {
        my $tag_emitter
          = $self->spelling_tag_emitter('spelling-error-in-patch-description',
            $patch_file);
        check_spelling($self->profile, $description,
            $self->group->spelling_exceptions,
            $tag_emitter, 0);
    }

    # Use --strip=1 to strip off the first layer of directory in case
    # the parent directory in which the patches were generated was
    # named "debian".  This will produce false negatives for --strip=0
    # patches that modify files in the debian/* directory, but as of
    # 2010-01-01, all cases where the first level of the patch path is
    # "debian/" in the archive are false positives.
    my $bytes = safe_qx('lsdiff', '--strip=1', $patch_file->unpacked_path);
    my $output = decode_utf8($bytes);

    my @debian_files = ($output =~ m{^((?:\./)?debian/.*)$}ms);

    $self->hint('patch-modifying-debian-files', $patch_file->name, $_)
      for @debian_files;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

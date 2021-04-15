# documentation/texinfo -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2001 Josip Rodin
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

package Lintian::Check::Documentation::Texinfo;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);
use List::SomeUtils qw(uniq);

use Lintian::Util qw(normalize_link_target);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

sub binary {
    my ($self) = @_;

    my $processable = $self->processable;

    my $info_dir = $processable->installed->resolve_path('usr/share/info/');
    return
      unless $info_dir;

    # Read package contents...
    foreach my $file ($info_dir->descendants) {
        # NB: file_info can be undef (e.g. symlinks)
        my $file_info = $file->file_info // $EMPTY;
        my $fname = $file->basename;

        next unless $file->is_symlink or $file->is_file;

        # Ignore dir files.  That's a different error which we already catch in
        # the files check.
        next if $fname =~ /^dir(?:\.old)?(?:\.gz)?/;

        # Analyze the file names making sure the documents are named
        # properly.  Note that Emacs 22 added support for images in
        # info files, so we have to accept those and ignore them.
        # Just ignore .png files for now.
        my @fname_pieces = split /\./, $fname;
        my $ext = pop @fname_pieces;
        if ($ext eq 'gz') { # ok!
            if ($file->is_file) {
                # compressed with maximum compression rate?
                if ($file_info !~ m/gzip compressed data/) {
                    $self->hint('info-document-not-compressed-with-gzip',
                        $file);
                } else {
                    if ($file_info !~ m/max compression/) {
                        $self->hint(
'info-document-not-compressed-with-max-compression',
                            $file
                        );
                    }
                }
            }
        } elsif ($ext =~ m/^(?:png|jpe?g)$/) {
            next;
        } else {
            push(@fname_pieces, $ext);
            $self->hint('info-document-not-compressed', $file);
        }
        my $infoext = pop @fname_pieces;
        unless ($infoext && $infoext =~ /^info(-\d+)?$/) { # it's not foo.info

            # it's not foo{,-{1,2,3,...}}
            $self->hint('info-document-has-wrong-extension', $file)
              if @fname_pieces;
        }

        # If this is the main info file (no numeric extension). make
        # sure it has appropriate dir entry information.
        if ($fname !~ /-\d+\.gz/ && $file_info =~ /gzip compressed data/) {
            if (!$file->is_open_ok) {
                # unsafe symlink, skip.  Actually, this should never
                # be true as "$file_info" for symlinks will not be
                # "gzip compressed data".  But for good measure.
                next;
            }

            open(my $fd, '<:gzip', $file->unpacked_path)
              or die encode_utf8('Cannot open ' . $file->unpacked_path);

            my ($section, $start, $end);
            while (my $line = <$fd>) {

                $section = 1
                  if $line =~ /^INFO-DIR-SECTION\s+\S/;

                $start   = 1
                  if $line =~ /^START-INFO-DIR-ENTRY\b/;

                $end     = 1
                  if $line =~ /^END-INFO-DIR-ENTRY\b/;
            }
            close($fd);

            $self->hint('info-document-missing-dir-section', $file)
              unless $section;

            $self->hint('info-document-missing-dir-entry', $file)
              unless $start && $end;
        }

        # Check each [image src=""] form in the info files.  The src
        # filename should be in the package.  As of Texinfo 5 it will
        # be something.png or something.jpg, but that's not enforced.
        #
        # See Texinfo manual (info "(texinfo)Info Format Image") for
        # details of the [image] form.  Bytes \x00,\x08 introduce it
        # (and distinguishes it from [image] appearing as plain text).
        #
        # String src="..." part has \" for literal " and \\ for
        # literal \, though that would be unlikely in filenames.  For
        # the tag() message show $src unbackslashed since that's the
        # filename sought.
        #
        if ($file->is_file && $fname =~ /\.info(?:-\d+)?\.gz$/) {

            open(my $fd, '<:gzip', $file->unpacked_path)
              or die encode_utf8('Cannot open ' . $file->unpacked_path);

            my $position = 1;
            while (my $line = <$fd>) {

                my @missing;
                while ($line =~ /[\0][\b]\[image src="((?:\\.|[^\"])+)"/smg) {

                    my $src = $1;
                    $src =~ s/\\(.)/$1/g;   # unbackslash

                    push(@missing, $src)
                      unless $processable->installed->lookup(
                        normalize_link_target('usr/share/info', $src));
                }

                $self->hint('info-document-missing-image-file',
                    $file, "(line $position)", $_)
                  for uniq @missing;

            } continue {
                ++$position;
            }

            close($fd);
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

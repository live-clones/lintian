# files/compressed -- lintian check script -*- perl -*-

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

package Lintian::files::compressed;

use strict;
use warnings;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $COMPRESS_FILE_EXTENSIONS
  = Lintian::Data->new('files/compressed-file-extensions',
    qr/\s++/,sub { return qr/\Q$_[0]\E/ });

# an OR (|) regex of all compressed extension
my $COMPRESS_FILE_EXTENSIONS_OR_ALL = sub { qr/(:?$_[0])/ }
  ->(
    join('|',
        map {$COMPRESS_FILE_EXTENSIONS->value($_) }
          $COMPRESS_FILE_EXTENSIONS->all));

# see tag duplicated-compressed-file
my $DUPLICATED_COMPRESSED_FILE_REGEX
  = qr/^(.+)\.(?:$COMPRESS_FILE_EXTENSIONS_OR_ALL)$/;

has changelog_timestamp => (is => 'rwp', default => 0);

sub setup {
    my ($self) = @_;

    # remains 0 if there is no timestamp
    my $changelog = $self->processable->changelog;
    if (defined $changelog) {

        my ($entry) = @{$changelog->entries};
        $self->_set_changelog_timestamp($entry->Timestamp)
          if $entry && $entry->Timestamp;
    }

    return;
}

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    my $architecture = $self->processable->field('architecture', '');
    my $multiarch = $self->processable->field('multi-arch', 'no');

    # both compressed and uncompressed present
    if ($file->name =~ $DUPLICATED_COMPRESSED_FILE_REGEX) {
        $self->tag('duplicated-compressed-file', $file->name)
          if $self->processable->installed->lookup($1);
    }

    # gzip files
    if ($file->name =~ m/\.gz$/) {

        if ($file->file_info !~ m/gzip compressed/) {
            $self->tag('gz-file-not-gzip', $file->name);
        } else {
            open(my $fd, '<', $file->unpacked_path);
            my $buff;

            # need at least 8 bytes
            die "reading $file failed: $!"
              unless sysread($fd, $buff, 1024) >= 8;

            # Extract the flags and the mtime.
            #  NN NN  NN NN, NN NN NN NN  - bytes read
            #  __ __  __ __,    $mtime    - variables
            my (undef, $mtime) = unpack('NN', $buff);
            close($fd);

            if ($mtime != 0) {
                if (   $multiarch eq 'same'
                    && $file->name !~ m/\Q$architecture\E/) {
                    $self->tag('gzip-file-is-not-multi-arch-same-safe',
                        $file->name);
                } else {
                    # see https://bugs.debian.org/762105
                    my $diff= $file->timestamp - $self->changelog_timestamp;

                    $self->tag('package-contains-timestamped-gzip',$file->name)
                      if $diff > 0;
                }
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

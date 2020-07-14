# files/compressed/gz -- lintian check script -*- perl -*-

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

package Lintian::files::compressed::gz;

use v5.20;
use warnings;
use utf8;

use Capture::Tiny qw(capture);
use Time::Piece;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

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

    if ($file->name =~ /\.gz$/si) {

        capture {
            $self->tag('broken-gz', $file->name)
              if system('gzip', '--test', $file->unpacked_path);
        };
    }

    # gzip files
    if ($file->file_info =~ /gzip compressed/) {

# get timestamp of first member; https://tools.ietf.org/html/rfc1952.html#page-5
        my $bytes = $file->magic(8);
        my (undef, $gziptime) = unpack('VV', $bytes);

        if (defined $gziptime && $gziptime != 0) {

            # see https://bugs.debian.org/762105
            my $time_from_build = $gziptime - $self->changelog_timestamp;
            if ($time_from_build > 0) {

                my $architecture
                  = $self->processable->fields->value('Architecture')// EMPTY;
                my $multiarch
                  = $self->processable->fields->value('Multi-Arch')// 'no';

                if ($multiarch eq 'same' && $file->name !~ /\Q$architecture\E/)
                {
                    $self->tag('gzip-file-is-not-multi-arch-same-safe',
                        $file->name);

                } else {
                    $self->tag('package-contains-timestamped-gzip',
                        $file->name,gmtime($gziptime)->datetime);
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

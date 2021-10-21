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

package Lintian::Check::Files::Compressed::Gz;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Time::Piece;

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# get timestamp of first member; https://tools.ietf.org/html/rfc1952.html#page-5
const my $GZIP_HEADER_SIZE => 8;

has changelog_timestamp => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # remains 0 if there is no timestamp
        my $changelog = $self->processable->changelog;
        if (defined $changelog) {

            my ($entry) = @{$changelog->entries};
            return $entry->Timestamp
              if $entry && $entry->Timestamp;
        }

        return 0;
    });

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    if ($file->name =~ /\.gz$/si) {

        safe_qx('gzip', '--test', $file->unpacked_path);

        $self->hint('broken-gz', $file->name)
          if $?;
    }

    # gzip files
    if ($file->file_info =~ /gzip compressed/) {

        my $bytes = $file->magic($GZIP_HEADER_SIZE);
        my (undef, $gziptime) = unpack('VV', $bytes);

        if (defined $gziptime && $gziptime != 0) {

            # see https://bugs.debian.org/762105
            my $time_from_build = $gziptime - $self->changelog_timestamp;
            if ($time_from_build > 0) {

                my $architecture
                  = $self->processable->fields->value('Architecture');
                my $multiarch
                  = $self->processable->fields->value('Multi-Arch') || 'no';

                if ($multiarch eq 'same' && $file->name !~ /\Q$architecture\E/)
                {
                    $self->hint('gzip-file-is-not-multi-arch-same-safe',
                        $file->name);

                } else {
                    $self->hint('package-contains-timestamped-gzip',
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

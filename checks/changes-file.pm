# changes-file -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2017-2019 Chris Lamb <lamby@debian.org>
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
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

package Lintian::changes_file;

use v5.20;
use warnings;
use utf8;
use autodie;

use Path::Tiny;

use Lintian::Data;
use Lintian::Util qw(get_file_checksum);

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $KNOWN_DISTS = Lintian::Data->new('changes-file/known-dists');

sub changes {
    my ($self) = @_;

    my $processable = $self->processable;
    my $group = $self->group;

    my $files = $processable->files;
    my $path
      = readlink(path($processable->basedir)->child('changes')->stringify);
    my %num_checksums;
    $path =~ s#/[^/]+$##;
    foreach my $file (keys %$files) {
        my $file_info = $files->{$file};

        # check section
        if (   ($file_info->{section} eq 'non-free')
            or ($file_info->{section} eq 'contrib')) {
            $self->tag('bad-section-in-changes-file', $file,
                $file_info->{section});
        }

        foreach my $alg (qw(Sha1 Sha256)) {
            my $checksum_info = $file_info->{checksums}{$alg};
            if (defined $checksum_info) {
                if ($file_info->{size} != $checksum_info->{filesize}) {
                    $self->tag('file-size-mismatch-in-changes-file', $file,
                           $file_info->{size} . ' != '
                          .$checksum_info->{filesize});
                }
            }
        }

        # check size
        my $filename = "$path/$file";
        my $size = -s $filename;

        if ($size ne $file_info->{size}) {
            $self->tag('file-size-mismatch-in-changes-file',
                $file,$file_info->{size} . " != $size");
        }

        # check checksums
        foreach my $alg (qw(Md5 Sha1 Sha256)) {
            next
              unless exists $file_info->{checksums}{$alg};

            my $real_checksum = get_file_checksum($alg, $filename);
            $num_checksums{$alg}++;

            if ($real_checksum ne $file_info->{checksums}{$alg}{sum}) {
                $self->tag('checksum-mismatch-in-changes-file',
                    "Checksum-$alg", $file);
            }
        }
    }

    my %debs = map { m/^([^_]+)_/ => 1 } grep { m/\.deb$/ } keys %$files;
    foreach my $pkg_name (keys %debs) {
        if ($pkg_name =~ m/^(.+)-dbgsym$/) {
            $self->tag('package-builds-dbg-and-dbgsym-variants',
                "$1-{dbg,dbgsym}")
              if exists $debs{"$1-dbg"};
        }
    }

    # Check that we have a consistent number of checksums and files
    foreach my $alg (keys %num_checksums) {
        my $seen = $num_checksums{$alg};
        my $expected = keys %{$files};
        $self->tag(
            'checksum-count-mismatch-in-changes-file',
            "$seen Checksum-$alg checksums != $expected files"
        ) if $seen != $expected;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

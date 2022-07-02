# changes-file -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2017-2019 Chris Lamb <lamby@debian.org>
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::ChangesFile;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use List::SomeUtils qw(uniq);
use Path::Tiny;

use Lintian::Util qw(get_file_checksum);

const my $NOT_EQUALS => q{!=};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub changes {
    my ($self) = @_;

    my %count_by_algorithm;

    for my $basename (keys %{$self->processable->files}) {

        my $details = $self->processable->files->{$basename};

        $self->hint('bad-section-in-changes-file', $basename,
            $details->{section})
          if $details->{section} eq 'non-free'
          || $details->{section} eq 'contrib';

        # take from location near input file
        my $physical_path
          = path($self->processable->path)->sibling($basename)->stringify;
        my $actual_size = -s $physical_path;

        # check size
        $self->hint('file-size-mismatch-in-changes-file',
            $basename, $details->{size}, $NOT_EQUALS, $actual_size)
          unless $details->{size} == $actual_size;

        for my $algorithm (qw(Md5 Sha1 Sha256)) {

            my $checksum_info = $details->{checksums}{$algorithm};
            next
              unless defined $checksum_info;

            $self->hint('file-size-mismatch-in-changes-file',
                $basename,$details->{size}, $NOT_EQUALS,
                $checksum_info->{filesize})
              unless $details->{size} == $checksum_info->{filesize};

            my $actual_checksum= get_file_checksum($algorithm, $physical_path);

            $self->hint('checksum-mismatch-in-changes-file',
                "Checksum-$algorithm", $basename)
              unless $checksum_info->{sum} eq $actual_checksum;

            ++$count_by_algorithm{$algorithm};
        }
    }

    my @installables= grep { m{ [.]deb $}x } keys %{$self->processable->files};
    my @installable_names = map { m{^ ([^_]+) _ }x } @installables;
    my @stems = uniq map { m{^ (.+) -dbg (?:sym) $}x } @installable_names;

    for my $stem (@stems) {

        my @conflicting = ("$stem-dbg", "$stem-dbgsym");

        my $lc = List::Compare->new(\@conflicting, \@installable_names);
        $self->hint('package-builds-dbg-and-dbgsym-variants',
            (sort @conflicting))
          if $lc->is_LsubsetR;
    }

    # Check that we have a consistent number of checksums and files
    for my $algorithm (keys %count_by_algorithm) {

        my $actual_count = $count_by_algorithm{$algorithm};
        my $expected_count = scalar keys %{$self->processable->files};

        $self->hint('checksum-count-mismatch-in-changes-file',
"$actual_count Checksum-$algorithm checksums != $expected_count files"
        ) if $actual_count != $expected_count;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# Hey emacs! This is a -*- Perl -*- script!
# Read_pkglists -- Perl utility functions to read Lintian's package lists

# Copyright (C) 1998 Christian Schwarz
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
package Read_pkglists;

use strict;
use warnings;

use Carp qw(croak);
use Util;
use base 'Exporter';

# these banner lines have to be changed with every incompatible change of the
# binary and source list file formats
## NB: If bumping the BINLIST_FORMAT, remember to kill the UDEB fall back
##     see read_bin_list
use constant BINLIST_FORMAT => "Lintian's list of binary packages in the archive--V4";
use constant SRCLIST_FORMAT => "Lintian's list of source packages in the archive--V4";

our @EXPORT = (qw(
    BINLIST_FORMAT
    SRCLIST_FORMAT
    read_src_list
    read_bin_list
));

sub read_src_list {
    my ($src_list) = @_;
    my %source_info;

    return {} unless $src_list && -s $src_list;

    open my $IN, '<', $src_list or croak "open $src_list: $!";

    # compatible file format?
    my $f;
    chop($f = <$IN>);
    if ($f ne SRCLIST_FORMAT) {
        close($IN);
        croak "$src_list has an incompatible file format";
    }

    # compatible format, so read file
    while (<$IN>) {
        chop;
        next if m/^\s*$/o;
        my ($src,$ver,$maint,$uploaders,$arch,$area,$std,$bin,$files,$file,$timestamp) = split(m/\;/o,$_);

        my $src_struct;
        %$src_struct =
            (
             'source' => $src,
             'version' => $ver,
             'maintainer' => $maint,
             'uploaders' => $uploaders,
             'architecture' => $arch,
             'area' => $area,
             'standards-version' => $std,
             'binary' => $bin,
             'files' => $files,
             'file' => $file,
             'timestamp' => $timestamp,
             );

        $source_info{$src} = $src_struct;
    }

    close($IN);
    return \%source_info;
}

# Previously udeb-files had a different format; allow parsing a udeb file as
# a binary file V4, assuming that is still the binary format at the time.
my $UDEBLIST_FORMAT = "Lintian's list of udeb packages in the archive--V3";


sub read_bin_list {
    my ($bin_list) = @_;
    my %binary_info;

    return {} unless $bin_list && -s $bin_list;

    open(my $IN, '<', $bin_list) or fail("open $bin_list: $!");

    # compatible file format?
    my $f;
    chop($f = <$IN>);
    if ($f ne BINLIST_FORMAT) {
        # accept the UDEB 3 header as alternative to the BIN 4 file
        if ($f ne $UDEBLIST_FORMAT || BINLIST_FORMAT !~ m/archive--V4$/o) {
            close($IN);
            croak "$bin_list has an incompatible file format";
        }
        # ok - was an UDEB 3 file, which is a BIN 4 file with a different header
    }

    # compatible format, so read file
    while (<$IN>) {
        chop;

        next if m/^\s*$/o;
        my ($bin,$ver,$source,$source_ver,$file,$timestamp,$area) = split(m/\;/o,$_);

        my $bin_struct;
        %$bin_struct =
          (
           'package' => $bin,
           'version' => $ver,
           'source' => $source,
           'source-version' => $source_ver,
           'file' => $file,
           'timestamp' => $timestamp,
           'area' => $area,
           );

        $binary_info{$bin} = $bin_struct;
    }

    close($IN);
    return \%binary_info;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# deb-format -- lintian check script -*- perl -*-

# Copyright (C) 2009 Russ Allbery
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::deb_format;
use strict;
use warnings;
use autodie;

use Lintian::Command qw(spawn);
use Lintian::Tags qw(tag);

# The files that contain error messages from tar, which we'll check and issue
# tags for if they contain something unexpected, and their corresponding tags.
# - These files are created by bin-pkg-control, index and unpacked respectively
our %ERRORS = ('control-errors'       => 'tar-errors-from-control',
               'control-index-errors' => 'tar-errors-from-control',
               'index-errors'         => 'tar-errors-from-data',
               'unpacked-errors'      => 'tar-errors-from-data');

sub run {

my (undef, $type, $info) = @_;

my $deb = $info->lab_data_path ('deb');

# Run ar t on the *.deb file.  deb will be a symlink to it.
my $okay = 0;
my $opts = {};
my $success = spawn ($opts, ['ar', 't', $deb]);
if ($success) {
    my @members = split("\n", ${ $opts->{out} });
    if (@members != 3) {
        my $count = scalar(@members);
        tag 'malformed-deb-archive',
            "found $count members instead of 3";
    } elsif ($members[0] ne 'debian-binary') {
        tag 'malformed-deb-archive',
            "first member $members[0] not debian-binary";
    } elsif ($members[1] ne 'control.tar.gz') {
        tag 'malformed-deb-archive',
            "second member $members[1] not control.tar.gz";
    } elsif ($members[2] eq 'data.tar.lzma') {
        # Ubuntu's archive allows lzma packages.
        tag 'lzma-deb-archive';
    } elsif ($members[2] !~ /^data\.tar\.(?:gz|bz2|xz)\z/) {
        tag 'malformed-deb-archive',
            "third member $members[2] not data.tar.(gz|bz2|xz)";
    } else {
        if ($type eq 'udeb' && $members[2] !~ m/^data\.tar\.[gx]z$/) {
            tag 'udeb-uses-unsupported-compression-for-data-tarball';
        }
        $okay = 1;
    }
} else {
    # unpack will probably fail so we'll never get here, but may as well be
    # complete just in case.
    my $error = ${ $opts->{err} };
    $error =~ s/\n.*//s;
    $error =~ s/^ar:\s*//;
    $error =~ s/^deb:\s*//;
    tag 'malformed-deb-archive', "ar error: $error";
}

# Check the debian-binary version number.  We probably won't get here because
# dpkg-deb will decline to unpack the deb, but be thorough just in case.  We
# may eventually have a case where dpkg supports a newer format but it's not
# permitted in the archive yet.
if ($okay) {
    $opts = {};
    $success = spawn ($opts, ['ar', 'p', $deb, 'debian-binary']);
    if (not $success) {
        tag 'malformed-deb-archive', 'cannot read debian-binary member';
    } elsif (${ $opts->{out} } !~ /^2\.\d+\n/) {
        my ($version) = split("\n", ${ $opts->{out} });
        tag 'malformed-deb-archive', "version $version not 2.0";
    }
}

# If either control-errors or index-errors exist, tar produced error output
# when processing the package.  We want to report those as tags unless they're
# just tar noise that doesn't represent an actual problem.
for my $file (keys %ERRORS) {
    my $tag = $ERRORS{$file};
    my $path = $info->lab_data_path ($file);
    if (-s $path) {
        open(my $fd, '<', $path);
        while ( my $line = <$fd> ) {
            chomp ($line);
            $line =~ s,^(?:[/\w]+/)?tar: ,,;

            # Record size errors are harmless.  Ignore implausibly old
            # timestamps in the data section since we already check for that
            # elsewhere, but still warn for control.
            next if $line =~ /^Record size =/;
            if ($tag eq 'tar-errors-from-data') {
                next if $line =~ /implausibly old time stamp/;
            }
            tag $tag, $line;
        }
        close($fd);
    }
}

}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

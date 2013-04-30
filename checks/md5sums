# md5sums -- lintian check script -*- perl -*-

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

package Lintian::md5sums;
use strict;
use warnings;
use autodie;

use Lintian::Tags qw(tag);

sub run {

my (undef, undef, $info) = @_;

my $control = $info->control('md5sums');

my %control_entry;
my %info_entry;

# The md5sums file should not be a symlink.  If it is, the best
# we can do is to leave it alone.
return if -l $control;

# Is there a md5sums control file?
unless (-f $control) {
    # ignore if package contains no files
    return 0 if -z $info->lab_data_path ('md5sums');

    # check if package contains non-conffiles
    # debhelper doesn't create entries in md5sums
    # for conffiles since this information would
    # be redundant
    my $only_conffiles = 1;
    foreach my $file ($info->sorted_index) {
        # Skip non-files, they will not appear in the md5sums file
        next unless $info->index ($file)->is_regular_file;
        unless ($info->is_conffile ($file)) {
            $only_conffiles = 0;
            last;
        }
    }

    tag 'no-md5sums-control-file' unless $only_conffiles;
    return 0;
}

# Is it empty? Then skip it. Tag will be issued by control-files
if (-z $control) {
    return 0;
}

# read in md5sums control file
open(my $fd, '<', $control);
while (my $line = <$fd>) {
    chop($line);
    next if $line =~ m/^\s*$/;
    if ($line =~ m{^([a-f0-9]+)\s*(?:\./)?(\S.*)$} && length($1) == 32) {
        $control_entry{$2} = $1;
    } else {
        tag 'malformed-md5sums-control-file', "line $.";
    }
}
close($fd);

for my $file (keys %control_entry) {

    my $md5sum = $info->md5sums->{$file};
    if (not defined $md5sum) {
        tag 'md5sums-lists-nonexisting-file', $file;
    } elsif ($md5sum ne $control_entry{$file}) {
        tag 'md5sum-mismatch', $file;
    }

    delete $info_entry{$file};
}
for my $file (keys %{ $info->md5sums }) {
    next if $control_entry{$file};
    tag 'file-missing-in-md5sums', $file
        unless ($info->is_conffile ($file) || $file =~ m%^var/lib/[ai]spell/.%o);
}

}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

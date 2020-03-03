# -*- perl -*-
#
# Lintian::Collect::Overrides -- lintian collection script for source packages

# Copyright © 1998 Richard Braakman
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

# This could be written more easily in shell script, but I'm trying
# to keep everything as perl to cut down on the number of processes
# that need to be started in a lintian scan.  Eventually all the
# perl code will be perl modules, so only one perl interpreter
# need be started.

package Lintian::Collect::Overrides;

use strict;
use warnings;
use autodie;

use Lintian::Util qw(gunzip_file is_ancestor_of);

=head1 NAME

Lintian::Collect::Overrides - collect override information

=head1 SYNOPSIS

    Lintian::Collect::Overrides::collect(undef, undef, undef);

=head1 DESCRIPTION

Lintian::Collect::Overrides collects override information.

=head1 INSTANCE METHODS

=over 4

=item collect

=cut

sub collect {
    my ($pkg, $type, $dir) = @_;

    my $unpackedpath = "$dir/unpacked";
    die 'wrong dir argument $dir'
      unless -d $unpackedpath;

    my $overridepath = "$dir/override";
    unlink($overridepath)
      if -e $overridepath;

    # pick the first
    my @candidates;
    if ($type eq 'source') {
        # prefer source/lintian-overrides to source.lintian-overrides
        @candidates = ('debian/source/lintian-overrides',
            'debian/source.lintian-overrides');
    } else {
        @candidates = ("usr/share/lintian/overrides/$pkg");
    }

    my $packageoverridepath;
    for my $relative (@candidates) {

        my $candidate = "$unpackedpath/$relative";
        if (-f $candidate) {
            $packageoverridepath = $candidate;

        } elsif (-f "$candidate.gz") {
            $packageoverridepath = "$candidate.gz";
        }

        last
          if $packageoverridepath;
    }

    return
      unless length $packageoverridepath;

    return
      unless is_ancestor_of($unpackedpath, $packageoverridepath);

    if ($packageoverridepath =~ /\.gz$/) {
        gunzip_file($packageoverridepath, $overridepath);
    } else {
        link($packageoverridepath, $overridepath);
    }

    return;
}

=back

=head1 AUTHOR

Originally written by Richard Braakman <dark@xs4all.nl> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

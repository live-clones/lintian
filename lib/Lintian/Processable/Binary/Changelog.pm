# -*- perl -*-
#
# Lintian::Processable::Binary::Changelog -- lintian collection script for source packages

# Copyright © 1998 Richard Braakman
# Copyright © 2019 Felix Lechner
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

package Lintian::Processable::Binary::Changelog;

use strict;
use warnings;
use autodie;

use File::Copy qw(copy);
use List::MoreUtils qw(first_value);
use Path::Tiny;

use Lintian::Util qw(is_ancestor_of safe_qx);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Binary::Changelog - collect changelog information

=head1 SYNOPSIS

    Lintian::Processable::Binary::Changelog::collect(undef, undef, undef);

=head1 DESCRIPTION

Lintian::Processable::Binary::Changelog collects changelog information.

=head1 INSTANCE METHODS

=over 4

=item add_changelog

=cut

sub add_changelog {
    my ($self, $pkg, undef, $dir) = @_;

    my $changelogpath = "$dir/changelog";
    unlink($changelogpath)
      if -e $changelogpath || -l $changelogpath;

    # Extract NEWS.Debian files as well, with similar precautions.
    # Ignore any symlinks to other packages here; in that case, we
    # just won't check the file.
    my $newspath = "$dir/NEWS.Debian";
    unlink($newspath)
      if -l $newspath
      or -e _;

    my $unpackedpath = "$dir/unpacked";
    my $packagepath = "$unpackedpath/usr/share/doc/$pkg";

    # pretend we did not find anything if parent dir is outside package
    return
      if -d $packagepath
      && !is_ancestor_of($unpackedpath, $packagepath);

    my $packagenewspath = "$packagepath/NEWS.Debian.gz";
    if (-f $packagenewspath) {
        if (-l $packagenewspath) {
            my $link = readlink($packagenewspath);
            if ($link =~ /\.\./
                || ($link =~ m%/% && $link !~ m%^[^/]+(?:/+[^/]+)*\z%)) {
                undef $packagenewspath;
            }
        }
        if ($packagenewspath) {
            my $contents = safe_qx('gunzip', '-c', $packagenewspath);
            path($newspath)->spew($contents);
        }
    }

    # pick the first existing file
    my @changelogfiles = (
        'changelog.Debian.gz','changelog.Debian',
        'changelog.debian.gz','changelog.debian',
        'changelog.gz','changelog',
    );

    my @candidatepaths = map { "$packagepath/$_" } @changelogfiles;
    my $packagechangelogpath = first_value { -l $_ || -f $_ } @candidatepaths;

    return
      unless defined $packagechangelogpath;

    # If the changelog file we found was a symlink, we have to be
    # careful.  It could be a symlink to some file outside of the
    # laboratory and we don't want to end up reading that file by
    # mistake.  Relative links within the same directory or to a
    # subdirectory we accept; anything else is replaced by an
    # intentionally broken symlink so that checks can do the right
    # thing.
    if (defined($packagechangelogpath) && -l $packagechangelogpath) {
        my $link = readlink($packagechangelogpath);
        if ($link =~ /\.\./
            || ($link =~ m%/% && $link !~ m%^[^/]+(?:/+[^/]+)*\z%)) {
            symlink("$dir/file-is-in-another-package", $changelogpath);
            undef $packagechangelogpath;
        } elsif (!-f $packagechangelogpath) {
            undef $packagechangelogpath;
        }
    }

    # If the changelog was a broken symlink, it will be undefined and we'll now
    # treat it the same as if we didn't find a changelog and do nothing.  If it
    # was a symlink, copy the file, since otherwise the relative symlinks are
    # going to break things.
    if (not defined $packagechangelogpath) {
        # no changelog found
    } elsif ($packagechangelogpath =~ /\.gz$/) {
        my $contents = safe_qx('gunzip', '-c', $packagechangelogpath);
        path($changelogpath)->spew($contents);
    } elsif (-f $packagechangelogpath && -l $packagechangelogpath) {
        copy($packagechangelogpath, $changelogpath)
          or die "cannot copy $packagechangelogpath: $!";
    } else {
        link($packagechangelogpath, $changelogpath);
    }

    if (   $packagechangelogpath
        && $packagechangelogpath !~ m/changelog\.debian/i) {
        # Either this is a native package OR a non-native package where the
        # debian changelog is missing.  checks/changelog is not too happy
        # with the latter case, so check looks like a Debian changelog.
        my @lines = path($changelogpath)->lines;
        my $ok = 0;
        for my $line (@lines) {
            next if $line =~ m/^\s*+$/o;
            # look for something like
            # lintian (2.5.3) UNRELEASED; urgency=low
            if ($line
                =~ m/^\S+\s*\([^\)]+\)\s*(?:UNRELEASED|(?:[^ \t;]+\s*)+)\;/o) {
                $ok = 1;
            }
            last;
        }
        # Remove it if it not the Debian changelog.
        unlink($changelogpath) unless $ok;
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

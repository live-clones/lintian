# -*- perl -*-
#
# Lintian::Processable::Binary::Copyright -- lintian collection script

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

package Lintian::Processable::Binary::Copyright;

use v5.20;
use warnings;
use utf8;
use autodie;

use File::Copy qw(copy);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Path::Tiny;

use Lintian::Util qw(is_ancestor_of);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Binary::Copyright - collect copyright information

=head1 SYNOPSIS

    Lintian::Processable::Binary::Copyright::collect(undef, undef, undef);

=head1 DESCRIPTION

Lintian::Processable::Binary::Copyright collects copyright information.

=head1 INSTANCE METHODS

=over 4

=item add_copyright

=cut

sub add_copyright {
    my ($self) = @_;

    my $unpackedpath = path($self->groupdir)->child('unpacked')->stringify;
    return
      unless -d $unpackedpath;

    my $copyrightpath = path($self->groupdir)->child('copyright')->stringify;
    unlink($copyrightpath)
      if -e $copyrightpath;

    my $packagepath = "$unpackedpath/usr/share/doc/" . $self->name;
    return
      unless -d $packagepath;

    # do not proceed if the parent dir is outside the package
    return
      unless is_ancestor_of($unpackedpath, $packagepath);

    my $packagecopyrightpath = "$packagepath/copyright";

    # make copy if symlink; hardlink could dangle; also check link path
    if (-l $packagecopyrightpath) {

        my $link = readlink($packagecopyrightpath);
        unless ($link =~ /\.\./
            || ($link =~ m%/% && $link !~ m%^[^/]+(?:/+[^/]+)*\z%)) {

            copy($packagecopyrightpath, $copyrightpath)
              or die "cannot copy $packagecopyrightpath: $!";
        }

    } elsif (-f $packagecopyrightpath) {
        link($packagecopyrightpath, $copyrightpath);

    } elsif (-f "$packagecopyrightpath.gz") {
        gunzip("$packagecopyrightpath.gz" => $copyrightpath)
          or die "gunzip $packagecopyrightpath failed: $GunzipError";
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

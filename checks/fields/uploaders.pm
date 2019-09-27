# fields/uploaders -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::fields::uploaders;

use strict;
use warnings;
use autodie;

use List::MoreUtils qw(true);

use Lintian::Check qw(check_maintainer);
use Lintian::Tags qw(tag);

sub always {
    my (undef, undef, $info, undef, undef) = @_;

    my $uploaders = $info->unfolded_field('uploaders');

    return
      unless defined $uploaders;

    # Note, not expected to hit on uploaders anymore, as dpkg
    # now strips newlines for the .dsc, and the newlines don't
    # hurt in debian/control

    # check for empty field see  #783628
    if($uploaders =~ m/,\s*,/) {
        tag 'uploader-name-missing','you have used a double comma';
        $uploaders =~ s/,\s*,/,/g;
    }

    my %duplicate_uploaders;
    my @list = map { split /\@\S+\K\s*,\s*/ }
      split />\K\s*,\s*/, $uploaders;

    for my $member (@list) {
        check_maintainer($member, 'uploader');
        if (   ((true { $_ eq $member } @list) > 1)
            and($duplicate_uploaders{$member}++ == 0)) {
            tag 'duplicate-uploader', $member;
        }
    }

    my $maintainer = $info->field('maintainer');
    if (defined $maintainer) {

        tag 'maintainer-also-in-uploaders'
          if $info->field('uploaders') =~ m/\Q$maintainer/;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

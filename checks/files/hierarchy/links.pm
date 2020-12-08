# files/symbolic-links/broken -- lintian check script -*- perl -*-
#
# Copyright © 2020 Felix Lechner
# Copyright © 2020 Chris Lamb <lamby@debian.org>
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

package Lintian::files::hierarchy::links;

use v5.20;
use warnings;
use utf8;
use autodie;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $ARROW => q{ -> };

sub visit_installed_files {
    my ($self, $file) = @_;

    # symbolic links only
    return
      unless $file->is_symlink;

    # only look at /usr/lib
    return
      unless $file->name =~ m{^usr/lib/};

    # must resolve
    my $target = $file->link_normalized;
    return
      unless defined $target;

    # see Bug#243158, Bug#964111
    my $restraint = $file->dirname;

    # either /usr/lib or one level below for architecture, if applicable
    $restraint =~ s{^((?:[^/]+/){3}).*$}{$1}s;

    $self->hint('breakout-link', $file->name . $ARROW .  $target)
      unless $target =~ m{^\Q$restraint\E};

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

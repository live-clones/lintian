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

package Lintian::Check::Files::Hierarchy::Links;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(any first_value);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SLASH => q{/};
const my $ARROW => q{ -> };

sub visit_installed_files {
    my ($self, $file) = @_;

    # symbolic links only
    return
      unless $file->is_symlink;

    my $target = $file->link_normalized;
    return
      unless defined $target;

    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};

    my $origin_dirname= first_value { $file->dirname eq $_ } @ldconfig_folders;

    # look only at links originating in common ld.so load paths
    return
      unless length $origin_dirname;

    my $target_dirname
      = first_value { (dirname($target) . $SLASH) eq $_ } @ldconfig_folders;
    $target_dirname //= $EMPTY;

    # no subfolders
    $self->hint('ldconfig-escape', $file->name . $ARROW .  $target)
      unless length $target_dirname;

    my @multiarch= values %{$self->profile->architectures->deb_host_multiarch};

    $self->hint('architecture-escape', $file->name . $ARROW .  $target)
      if (any { basename($origin_dirname) eq $_ } @multiarch)
      && (any { $target_dirname eq "$_/" } qw{lib usr/lib usr/local/lib});

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

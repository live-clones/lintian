# maintainer_scripts::adduser -- lintian check script -*- perl -*-

# Copyright (C) 2020 Topi Miettinen
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::MaintainerScripts::Adduser;

use v5.20;
use warnings;
use utf8;

use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_control_files {
    my ($self, $item) = @_;

    # get maintainer scripts
    return
      unless $item->is_maintainer_script;

    return
      unless $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $continuation = undef;

    my $position = 1;
    while (my $line = <$fd>) {

        chomp $line;

        # merge lines ending with '\'
        if (defined $continuation) {
            $line = $continuation . $line;
            $continuation = undef;
        }

        if ($line =~ /\\$/) {
            $continuation = $line;
            $continuation =~ s/\\$/ /;
            next;
        }

        # trim right
        $line =~ s/\s+$//;

        # skip empty lines
        next
          if $line =~ /^\s*$/;

        # skip comments
        next
          if $line =~ /^[#\n]/;

        $self->pointed_hint('adduser-with-home-var-run',
            $item->pointer($position))
          if $line =~ /adduser .*--home +\/var\/run/;

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

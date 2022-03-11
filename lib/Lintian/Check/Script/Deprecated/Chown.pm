# script/deprecated/chown -- lintian check script -*- perl -*-

# Copyright © 2022 Felix Lechner
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

package Lintian::Check::Script::Deprecated::Chown;

use v5.20;
use warnings;
use utf8;

use Unicode::UTF8 qw(valid_utf8 encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub check_item {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->is_script;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {

        chomp $line;

        next
          if $line =~ /^#/;

        next
          unless length $line;

        if ($line =~ m{ \b chown \s+ (?: -\S+ \s+ )* ( \S+ [.] \S+ ) \b }x) {

            my $ownership = $1;

            $self->pointed_hint('chown-with-dot', $item->pointer($position),
                $ownership);
        }

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

sub visit_control_files {
    my ($self, $item) = @_;

    $self->check_item($item);

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    $self->check_item($item);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

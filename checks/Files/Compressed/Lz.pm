# files/compressed/lz -- lintian check script -*- perl -*-

# Copyright © 2020 Chris Lamb
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

package Lintian::Check::Files::Compressed::Lz;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(first_value);

use Lintian::IPC::Run3 qw(safe_qx);
use Lintian::Util qw(locate_executable);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has lzip_command => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $command = first_value { locate_executable($_) } qw(lzip clzip);

        return $command;
    });

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    my $command = $self->lzip_command;
    return
      unless length $command;

    if ($file->name =~ /\.lz$/si) {

        safe_qx($command, '--test', $file->unpacked_path);

        $self->hint('broken-lz', $file->name)
          if $?;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# languages/java/bytecode -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Languages::Java::Bytecode;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $MAGIC_BYTE_SIZE => 4;

sub visit_installed_files {
    my ($self, $file) = @_;

    # .class (compiled Java files)
    if (   $file->name =~ /\.class$/
        && $file->name !~ /(?:WEB-INF|demo|doc|example|sample|test)/) {

        my $magic = $file->magic($MAGIC_BYTE_SIZE);

        $self->hint('package-installs-java-bytecode', $file->name)
          if $magic eq "\xCA\xFE\xBA\xBE";
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
